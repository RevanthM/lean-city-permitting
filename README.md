# Los Angeles permit intake in Lean

An executable research prototype for **new-building intake routing in the City of Los Angeles and unincorporated Los Angeles County**. These are distinct jurisdictions. Supported requests go to LADBS intake or LA County Public Works Building and Safety / EPIC-LA intake; unresolved requests go to review. The checker does not issue permits or decide code compliance.

The initial release contains **14 proved invariants and 30 synthetic fixtures**. All authored proofs are checked by Lean 4.35.0; there are no external Lean packages.

```sh
lake build
lake exe fixtures
sh scripts/check-proof-holes.sh
```

Install [Lean and Lake](https://lean-lang.org/install/). The `lean-toolchain` file pins `leanprover/lean4:v4.35.0`. CI runs the same checks.

## City versus county comes first

`Jurisdiction` distinguishes `cityLA`, `unincorporatedLACounty`, `otherIncorporatedCity`, and `unknown`. An LA mailing address cannot establish the permitting authority. The model requires an externally reviewed official parcel-lookup reference with a registered lookup source identifier, a matching parcel identifier and jurisdiction, and an explicit review attestation. A mailing-address-only certificate fails even if every other field is acceptable.

For a real workflow, obtain and review jurisdiction evidence through official city/county parcel and service tools such as [City ZIMAS](https://dbs.lacity.gov/services/zoning); the County directs applicants to its [Building and Safety service lookup](https://permits.lacounty.gov/permits/building-and-safety/) and [jurisdiction guidance](https://planning.lacounty.gov/unincorporated-los-angeles-county/). This prototype does not query a GIS, authenticate a lookup, or calculate a boundary. Its examples use synthetic lookup references.

Other incorporated cities are unsupported, including cities that contract with County services. They go to review; the checker does not assume every property geographically inside LA County belongs in the unincorporated County workflow. County planning, city planning, building safety, fire, and other agency jurisdictions need separate rules.

## What the checker checks

- The entire supplied policy matches the compiled policy for the request's jurisdiction, including its source identifier, revision, and fixture dates.
- A valid calendar date falls in the explicit research window: November 15 through November 30, 2026. This is a synthetic applicability horizon, **not a statute's effective period**.
- Official parcel-lookup evidence is reviewed, references the same parcel, and attests to a supported jurisdiction.
- A reviewer confirms the new-building scope and flags neither retained existing elements nor special conditions.
- Address, parcel, drawings, and applicant references contain a non-whitespace character. These are model intake requirements, not either agency's complete submission checklist.
- A scope evidence span is nonempty, within the applicant note, and exactly matches its supplied quote.

The inputs remain a trust boundary. The checker verifies relationships among supplied fields; it does not establish a boundary lookup's authenticity, a drawing's adequacy, or the correctness of a language interpretation. Text saying “new building” does not itself establish a legal work classification.

## Files and evaluation

- `CityPermitting.lean`: types, registry, checker, and 14 theorems.
- `Main.lean`: three successful routing cases and 27 review cases.
- [Whitepaper](docs/whitepaper.md): architecture, theorem inventory, evaluation, and limitations.
- [Source manifest](docs/sources.json): official source links and the bounded interpretation.

Negative cases include City/County policy confusion, unsupported and unknown jurisdictions, mailing-only evidence, wrong lookup parcel/jurisdiction, missing lookup reference, stale model dates, altered policy revision, missing references, unsupported scopes, and fabricated source spans. Ordinary repairs, additions, demolition, and other unsupported work receive review without an exemption decision.

A language model can propose structured scope facts and quotations before this checker runs. The same fixed structured input and policy yield the same routing result. Neural extraction and semantic review require their own validation.

MIT applies to authored code and prose. Linked agency materials retain their own terms. No affiliation with LADBS, LA County Public Works, or LA County Planning is implied.

## Publication

Read the [Matha Labs research article](https://www.mathalabs.com/blog/city-permitting-in-lean/), [download the whitepaper PDF](docs/whitepaper.pdf), or inspect its [editable source](docs/whitepaper.md). The published evaluation uses synthetic fixtures only.
