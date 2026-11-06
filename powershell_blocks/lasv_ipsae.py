#!/usr/bin/env python3
"""
lasv_ipsae.py -- multichain ipSAE scorer for Boltz protein-design results
downloaded by the PowerShell `boltz-api.exe download-results` layout.

Layout expected (what Block 2 produces):
    <runDir>/results/<design>/.../*.cif
    <runDir>/results/<design>/.../*pae*.npz
    <runDir>/results/<design>/.../metadata.json

Scoring: runs ipsae.calculate_ipsae() over the WHOLE complex, then reads
ipsae_d0chn_asym and reports, per design:
  - ipsae_max / ipsae_pair  : best target<->binder score over both directions
  - ipsae_<chain>           : per-target-chain max vs any binder chain
  - ipsae_epitope           : max over EPITOPE_CHAINS   (on-target)
  - ipsae_offtarget         : max over DECOY_CHAINS     (off-target drift)
  - d0chn / n0chn           : the derived d0 for the best pair (NOT settable)
  - verdict                 : GOOD / BORDERLINE / OFF_TARGET / BAD
"""
import argparse, csv, glob, json, os, sys
from concurrent.futures import ProcessPoolExecutor, as_completed

# ---------------- verdict thresholds (tune here) ----------------
IPSAE_GOOD       = 0.50   # ipSAE paper: >=0.5 indicates a likely real interface
IPSAE_BORDERLINE = 0.30   # plausible but under-confident interface
IPSAE_WEAK       = 0.05   # below this there is effectively no interface at all
MAX_IPAE_GOOD    = 10.0   # min_interaction_pae must be at or below this for GOOD
DRIFT_MARGIN     = 0.02   # off-target must beat on-target by this much to call drift
# ----------------------------------------------------------------


def _import_ipsae():
    """Import the INSTALLED ipsae package, never a stray ipsae.py sitting next to
    this script. Python puts the script's own directory first on sys.path, so an old
    standalone ipsae.py in the same folder shadows the package -- and that script
    parses sys.argv at import time, which blows up with a float() error on our flags.
    Also no-ops the output writer, which does ord(chain)-ord('A') and cannot handle
    multi-char chain ids like ABH1/ABL1."""
    here = os.path.dirname(os.path.abspath(__file__))
    for p in list(sys.path):
        if p in ("", ".") or (p and os.path.isdir(p) and os.path.abspath(p) == here):
            try:
                sys.path.remove(p)
            except ValueError:
                pass
    for mod in ("ipsae", "ipsae.core"):
        sys.modules.pop(mod, None)

    import ipsae
    if not hasattr(ipsae, "calculate_ipsae"):
        raise RuntimeError(
            f"'import ipsae' resolved to {getattr(ipsae, '__file__', '?')}, which is not "
            "the installed package. Delete or rename that file, or run 'pip install ipsae'."
        )
    import ipsae.core as core
    core.IpsaeCalculator._save_outputs = lambda self, *a, **k: None
    return ipsae


def _lookup(mat, a, b):
    """mat[a][b] tolerating np.str_ keys."""
    v = mat.get(a, {}).get(b)
    if v is not None:
        return v
    for k in mat:
        if str(k) == a:
            row = mat[k]
            if b in row:
                return row[b]
            for k2 in row:
                if str(k2) == b:
                    return row[k2]
    return None


def _find(design_dir, pattern, exclude=None):
    hits = glob.glob(os.path.join(design_dir, "**", pattern), recursive=True)
    if exclude:
        hits = [h for h in hits if exclude not in os.path.basename(h)]
    return sorted(hits)[0] if hits else None


def score_one(args):
    design_dir, binder_ids, pae_cutoff, dist_cutoff = args
    rid = os.path.basename(design_dir.rstrip(os.sep))
    row = {"result_id": rid, "ipsae_max": None, "ipsae_pair": None,
           "per_target": {}, "d0chn": None, "n0chn": None, "status": "ok"}

    cif = _find(design_dir, "*.cif")
    npz = _find(design_dir, "*pae*.npz")
    meta = _find(design_dir, "metadata.json")

    if not (cif and npz):
        row["status"] = "missing_cif_or_npz"
        return row

    try:
        ipsae = _import_ipsae()
        res = ipsae.calculate_ipsae(npz, cif, float(pae_cutoff), float(dist_cutoff), output_dir=None)
        sc = res.get("ipsae_scores", {})
        asym = sc.get("ipsae_d0chn_asym", {})
        d0chn_m, n0chn_m = sc.get("d0chn", {}), sc.get("n0chn", {})

        chains = sorted(str(c) for c in asym.keys())
        bset = set(map(str, binder_ids or []))
        binder = [c for c in chains if c in bset] or [c for c in chains if len(c) > 1]
        target = [c for c in chains if c not in binder]

        best, best_pair, best_d0, best_n0 = None, None, None, None
        per_target = {}
        for t in target:
            tmax = None
            for b in binder:
                for a, bb in ((t, b), (b, t)):
                    v = _lookup(asym, a, bb)
                    if v is None:
                        continue
                    v = float(v)
                    if tmax is None or v > tmax:
                        tmax = v
                    if best is None or v > best:
                        best, best_pair = v, f"{a}->{bb}"
                        d0v, n0v = _lookup(d0chn_m, a, bb), _lookup(n0chn_m, a, bb)
                        best_d0 = float(d0v) if d0v is not None else None
                        best_n0 = float(n0v) if n0v is not None else None
            per_target[t] = tmax

        row.update(ipsae_max=best, ipsae_pair=best_pair, per_target=per_target,
                   d0chn=best_d0, n0chn=best_n0,
                   target_chains="+".join(target), binder_chains="+".join(binder))
    except Exception as e:  # noqa: BLE001
        row["status"] = f"error:{type(e).__name__}:{e}"

    # inline Boltz metrics + designed sequences from metadata.json
    if meta:
        try:
            m = json.load(open(meta))
            row["iptm"] = (m.get("metrics") or {}).get("iptm")
            row["min_interaction_pae"] = (m.get("metrics") or {}).get("min_interaction_pae")
            row["binding_confidence"] = (m.get("metrics") or {}).get("binding_confidence")
            row["structure_confidence"] = (m.get("metrics") or {}).get("structure_confidence")
            for ent in (m.get("entities") or []):
                for cid in (ent.get("chain_ids") or []):
                    row[f"seq_{cid}"] = ent.get("value")
        except Exception:  # noqa: BLE001
            pass
    return row


def verdict(r, epitope, decoys):
    """Classify a design. Drift is judged RELATIVELY (off vs on) because real
    ipSAE values on large targets often sit well below the 0.5 literature bar,
    and an absolute gate would never fire."""
    if r["status"] != "ok" or r.get("ipsae_max") is None:
        return "ERROR", r["status"]
    pt = r.get("per_target") or {}
    epi = max([v for c, v in pt.items() if c in epitope and v is not None] or [0.0])
    off = max([v for c, v in pt.items() if c in decoys and v is not None] or [0.0])
    r["ipsae_epitope"], r["ipsae_offtarget"] = epi, off
    ipae = r.get("min_interaction_pae")
    r["on_target"] = epi >= off

    # nothing is binding anywhere -> no interface, drift question is moot
    if max(epi, off) < IPSAE_WEAK:
        return "BAD", f"no interface anywhere (epi={epi:.3f}, off={off:.3f})"
    # binder prefers a chain we did not ask for
    if off > epi + DRIFT_MARGIN:
        return "OFF_TARGET", f"drifts to decoy chains (off={off:.3f} vs epi={epi:.3f})"
    if epi >= IPSAE_GOOD and (ipae is None or float(ipae) <= MAX_IPAE_GOOD):
        return "GOOD", f"on-target ipSAE={epi:.3f}, min_ipae={ipae}"
    if epi >= IPSAE_BORDERLINE:
        return "BORDERLINE", f"on-target ipSAE={epi:.3f}, under {IPSAE_GOOD}"
    if epi >= IPSAE_WEAK:
        return "WEAK", f"weak but on-target interface (ipSAE={epi:.3f})"
    return "BAD", f"no real interface on epitope (ipSAE={epi:.3f})"


def main():
    ap = argparse.ArgumentParser(description="Multichain ipSAE scoring for Boltz LASV designs.")
    ap.add_argument("--run-dir", required=True, help=r"e.g. C:\Users\HP\Downloads\PDFA-LASV-opt1-blockBCF-10-v2")
    ap.add_argument("--epitope", default="A,D,E", help="on-target chains")
    ap.add_argument("--decoys", default="B,C,F", help="off-target chains to flag drift")
    ap.add_argument("--binders", default="ABH1,ABL1")
    ap.add_argument("--pae-cutoff", type=float, default=15.0, help="15 = large-target rule; try 18 for very large targets")
    ap.add_argument("--dist-cutoff", type=float, default=10.0)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 4) - 1))
    ap.add_argument("--out-csv", default=None)
    a = ap.parse_args()

    epitope = [c.strip() for c in a.epitope.split(",") if c.strip()]
    decoys  = [c.strip() for c in a.decoys.split(",") if c.strip()]
    binders = [c.strip() for c in a.binders.split(",") if c.strip()]

    results_root = os.path.join(a.run_dir, "results")
    dirs = sorted(d for d in glob.glob(os.path.join(results_root, "*")) if os.path.isdir(d))
    if not dirs:
        sys.exit(f"No design folders under {results_root}")

    print(f"scoring {len(dirs)} designs | pae_cutoff={a.pae_cutoff} dist_cutoff={a.dist_cutoff} | workers={a.workers}")
    tasks = [(d, binders, a.pae_cutoff, a.dist_cutoff) for d in dirs]
    rows, done = [], 0
    with ProcessPoolExecutor(max_workers=a.workers) as ex:
        futs = [ex.submit(score_one, t) for t in tasks]
        for fut in as_completed(futs):
            rows.append(fut.result())
            done += 1
            if done % 25 == 0 or done == len(tasks):
                print(f"  {done}/{len(tasks)} scored")

    target_chains = sorted({t for r in rows for t in (r.get("per_target") or {})})
    seq_cols = sorted({k for r in rows for k in r if k.startswith("seq_")})
    for r in rows:
        pt = r.get("per_target") or {}
        for t in target_chains:
            r[f"ipsae_{t}"] = pt.get(t)
        r["verdict"], r["verdict_reason"] = verdict(r, epitope, decoys)

    rows.sort(key=lambda r: (r.get("ipsae_epitope") is not None,
                             r.get("ipsae_epitope") if r.get("ipsae_epitope") is not None else -1),
              reverse=True)

    out_csv = a.out_csv or os.path.join(a.run_dir, "ipsae_multichain_ranking.csv")
    cols = (["rank", "result_id", "verdict", "verdict_reason",
             "ipsae_epitope", "ipsae_offtarget", "on_target", "ipsae_max", "ipsae_pair"]
            + [f"ipsae_{t}" for t in target_chains]
            + ["d0chn", "n0chn", "target_chains", "binder_chains",
               "iptm", "min_interaction_pae", "binding_confidence", "structure_confidence", "status"]
            + seq_cols)
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for i, r in enumerate(rows, 1):
            r["rank"] = i
            w.writerow({c: r.get(c) for c in cols})

    counts = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    print(f"\nDONE -> {out_csv}")
    print("verdicts:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    if rows and rows[0].get("d0chn"):
        print(f"d0chn (best pair, design 1): {rows[0]['d0chn']:.2f}  [derived from n0chn={rows[0].get('n0chn')}]")
    print(f"\nTOP 10 by on-target ipSAE (epitope {'+'.join(epitope)}):")
    for r in rows[:10]:
        epi = r.get("ipsae_epitope"); off = r.get("ipsae_offtarget")
        print(f"  {r['rank']:>2}. {r['result_id']}  epi={epi if epi is None else round(epi,3)}"
              f"  off={off if off is None else round(off,3)}  [{r.get('ipsae_pair')}]"
              f"  iptm={r.get('iptm')}  min_ipae={r.get('min_interaction_pae')}  -> {r['verdict']}")


if __name__ == "__main__":
    main()
