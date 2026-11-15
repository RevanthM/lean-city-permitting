import CityPermitting

open CityPermitting

def baseRequest (jurisdiction : Jurisdiction) : Request :=
  { jurisdiction := jurisdiction
    onDate := 20261115
    scope := .newBuilding
    note := "new building"
    scopeEvidence := { start := 0, length := 12, quote := "new building" }
    scopeReviewed := true
    jurisdictionEvidence := {
      source := .reviewedOfficialParcelLookup
      lookupReference := "SYNTHETIC REVIEWED OFFICIAL LOOKUP"
      lookupSourceId := lookupSourceFor jurisdiction
      parcelReference := "SYNTHETIC PARCEL"
      jurisdiction := jurisdiction
      reviewed := true }
    retainsExistingElements := false
    specialConditions := false
    address := "SYNTHETIC ADDRESS"
    parcelReference := "SYNTHETIC PARCEL"
    drawingsReference := "SYNTHETIC DRAWINGS"
    applicantReference := "SYNTHETIC APPLICANT" }

def cases : List (String × Policy × Request × Decision) :=
  let la := baseRequest .cityLA
  let county := baseRequest .unincorporatedLACounty
  let p := policyFor .cityLA
  [ ("LA City new-building intake", p, la, .routed .laLADBS)
  , ("unincorporated LA County intake", policyFor .unincorporatedLACounty, county, .routed .laCountyPublicWorksEPICLA)
  , ("County policy cannot route City parcel", policyFor .unincorporatedLACounty, la, .needsReview .untrustedPolicy)
  , ("other incorporated city unsupported", policyFor .otherIncorporatedCity, baseRequest .otherIncorporatedCity, .needsReview .unsupportedJurisdiction)
  , ("unknown jurisdiction unsupported", policyFor .unknown, baseRequest .unknown, .needsReview .unsupportedJurisdiction)
  , ("unregistered revision", { p with revision := "invented" }, la,
      .needsReview .untrustedPolicy)
  , ("caller extends model window", { p with windowEnd := 20300101 }, la,
      .needsReview .untrustedPolicy)
  , ("before model window", p, { la with onDate := 20261114 },
      .needsReview .outsideModelWindow)
  , ("end boundary excluded", p, { la with onDate := 20261201 },
      .needsReview .outsideModelWindow)
  , ("invalid calendar day", p, { la with onDate := 20261131 },
      .needsReview .outsideModelWindow)
  , ("jurisdiction unreviewed", p, { la with jurisdictionEvidence := { la.jurisdictionEvidence with reviewed := false } }, .needsReview .missingJurisdictionEvidence)
  , ("mailing address cannot establish jurisdiction", p, { la with jurisdictionEvidence := { la.jurisdictionEvidence with source := .mailingAddressOnly } }, .needsReview .missingJurisdictionEvidence)
  , ("lookup for wrong jurisdiction", p, { la with jurisdictionEvidence := { la.jurisdictionEvidence with jurisdiction := .unincorporatedLACounty } }, .needsReview .missingJurisdictionEvidence)
  , ("lookup for wrong parcel", p, { la with jurisdictionEvidence := { la.jurisdictionEvidence with parcelReference := "DIFFERENT PARCEL" } }, .needsReview .missingJurisdictionEvidence)
  , ("wrong lookup source", p, { la with jurisdictionEvidence := { la.jurisdictionEvidence with lookupSourceId := "mailing-directory" } }, .needsReview .missingJurisdictionEvidence)
  , ("missing lookup reference", p, { la with jurisdictionEvidence := { la.jurisdictionEvidence with lookupReference := "" } }, .needsReview .missingJurisdictionEvidence)
  , ("ordinary repair unsupported", p, { la with scope := .ordinaryRepair },
      .needsReview .unsupportedScope)
  , ("addition unsupported", p, { la with scope := .addition },
      .needsReview .unsupportedScope)
  , ("retained existing elements", p, { la with retainsExistingElements := true },
      .needsReview .retainedElements)
  , ("special conditions need review", p, { la with specialConditions := true },
      .needsReview .specialConditions)
  , ("missing address", p, { la with address := "" }, .needsReview .missingIntakeFacts)
  , ("whitespace address", p, { la with address := "  \t " }, .needsReview .missingIntakeFacts)
  , ("missing parcel reference", p, { la with parcelReference := "", jurisdictionEvidence := { la.jurisdictionEvidence with parcelReference := "" } },
      .needsReview .missingIntakeFacts)
  , ("missing drawings", p, { la with drawingsReference := "" },
      .needsReview .missingIntakeFacts)
  , ("missing applicant", p, { la with applicantReference := "" },
      .needsReview .missingIntakeFacts)
  , ("fabricated quote", p, { la with scopeEvidence := { start := 0, length := 12, quote := "not in note" } }, .needsReview .ungroundedEvidence)
  , ("out of bounds span", p, { la with scopeEvidence := { start := 10, length := 12, quote := "new building" } }, .needsReview .ungroundedEvidence)
  , ("empty span", p, { la with scopeEvidence := { start := 0, length := 0, quote := "" } },
      .needsReview .ungroundedEvidence)
  , ("scope not reviewed", p, { la with scopeReviewed := false },
      .needsReview .unreviewedScope)
  , ("last included fixture date", p, { la with onDate := 20261130 }, .routed .laLADBS)
  ]

def main : IO Unit := do
  for (name, policy, request, expected) in cases do
    let actual := evaluate policy request
    if actual != expected then
      throw (IO.userError s!"FAIL {name}: expected {repr expected}, got {repr actual}")
    IO.println s!"PASS {name}"
  IO.println s!"{cases.length} synthetic fixtures passed. No permit was granted."
