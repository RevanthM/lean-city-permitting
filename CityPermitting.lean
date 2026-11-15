import Std

/-! A bounded intake router. None of its constructors grants permission to build. -/
namespace CityPermitting

inductive Jurisdiction where
  | cityLA | unincorporatedLACounty | otherIncorporatedCity | unknown
  deriving DecidableEq, BEq, Repr

inductive Scope where
  | newBuilding | ordinaryRepair | addition | demolition | other
  deriving DecidableEq, BEq, Repr

inductive IntakeRoute where
  | laLADBS | laCountyPublicWorksEPICLA
  deriving DecidableEq, BEq, Repr

def routeFor : Jurisdiction → Option IntakeRoute
  | .cityLA => some .laLADBS
  | .unincorporatedLACounty => some .laCountyPublicWorksEPICLA
  | .otherIncorporatedCity | .unknown => none

def Supported (j : Jurisdiction) : Prop :=
  j = .cityLA ∨ j = .unincorporatedLACounty

instance (j : Jurisdiction) : Decidable (Supported j) := by
  unfold Supported
  infer_instance

structure Policy where
  jurisdiction : Jurisdiction
  sourceId : String
  revision : String
  windowStart : Nat
  windowEnd : Nat
  deriving DecidableEq, BEq, Repr

/- These dates are a RESEARCH FIXTURE applicability window, not legal effective dates.
   The whole policy is compared to this compiled registry, preventing caller-chosen windows. -/
def policyFor (jurisdiction : Jurisdiction) : Policy :=
  { jurisdiction := jurisdiction
    sourceId := match jurisdiction with
      | .cityLA => "la-city-ladbs-new-building-intake"
      | .unincorporatedLACounty => "la-unincorporated-county-new-building-intake"
      | .otherIncorporatedCity | .unknown => "unsupported-jurisdiction"
    revision := "research-la-snapshot-2026-11-15"
    windowStart := 20261115
    windowEnd := 20261201 }

inductive JurisdictionSource where
  | reviewedOfficialParcelLookup | mailingAddressOnly | unknown
  deriving DecidableEq, BEq, Repr

def lookupSourceFor : Jurisdiction → String
  | .cityLA => "la-city-zimas"
  | .unincorporatedLACounty => "la-county-publicworks-service-locator"
  | .otherIncorporatedCity | .unknown => "unsupported-jurisdiction"

structure JurisdictionEvidence where
  source : JurisdictionSource
  lookupReference : String
  lookupSourceId : String
  parcelReference : String
  jurisdiction : Jurisdiction
  reviewed : Bool
  deriving DecidableEq, BEq, Repr

structure Span where
  start : Nat
  length : Nat
  quote : String
  deriving DecidableEq, BEq, Repr

def Grounded (text : String) (span : Span) : Prop :=
  span.length > 0 ∧ span.start + span.length ≤ text.length ∧
    String.ofList ((text.toList.drop span.start).take span.length) = span.quote

instance (text : String) (span : Span) : Decidable (Grounded text span) := by
  unfold Grounded
  infer_instance

structure Request where
  jurisdiction : Jurisdiction
  onDate : Nat
  scope : Scope
  note : String
  scopeEvidence : Span
  scopeReviewed : Bool
  jurisdictionEvidence : JurisdictionEvidence
  retainsExistingElements : Bool
  specialConditions : Bool
  address : String
  parcelReference : String
  drawingsReference : String
  applicantReference : String
  deriving DecidableEq, BEq, Repr

/- The four references are a model checklist, not an exhaustive city's submission checklist. -/
def nonblank (s : String) : Bool := s.toList.any (fun c => !c.isWhitespace)

def DocumentsPresent (r : Request) : Prop :=
  nonblank r.address = true ∧ nonblank r.parcelReference = true ∧
    nonblank r.drawingsReference = true ∧ nonblank r.applicantReference = true

instance (r : Request) : Decidable (DocumentsPresent r) := by
  unfold DocumentsPresent
  infer_instance

/- An externally reviewed official lookup, tied to the same parcel. Mailing text alone fails. -/
def JurisdictionVerified (r : Request) : Prop :=
  Supported r.jurisdiction ∧
  r.jurisdictionEvidence.source = .reviewedOfficialParcelLookup ∧
  r.jurisdictionEvidence.reviewed = true ∧
  r.jurisdictionEvidence.jurisdiction = r.jurisdiction ∧
  r.jurisdictionEvidence.parcelReference = r.parcelReference ∧
  nonblank r.jurisdictionEvidence.lookupReference = true ∧
  r.jurisdictionEvidence.lookupSourceId = lookupSourceFor r.jurisdiction

instance (r : Request) : Decidable (JurisdictionVerified r) := by
  unfold JurisdictionVerified
  infer_instance

def daysInMonth (year month : Nat) : Nat :=
  if month = 2 then
    if year % 400 = 0 ∨ (year % 4 = 0 ∧ year % 100 ≠ 0) then 29 else 28
  else if month = 4 ∨ month = 6 ∨ month = 9 ∨ month = 11 then 30 else 31

def ValidDate (date : Nat) : Prop :=
  let year := date / 10000
  let month := (date / 100) % 100
  let day := date % 100
  year > 0 ∧ month > 0 ∧ month ≤ 12 ∧ day > 0 ∧ day ≤ daysInMonth year month

instance (date : Nat) : Decidable (ValidDate date) := by
  unfold ValidDate
  infer_instance

def InWindow (p : Policy) (r : Request) : Prop :=
  ValidDate r.onDate ∧ p.windowStart ≤ r.onDate ∧ r.onDate < p.windowEnd

instance (p : Policy) (r : Request) : Decidable (InWindow p r) := by
  unfold InWindow
  infer_instance

def Eligible (p : Policy) (r : Request) : Prop :=
  p = policyFor r.jurisdiction ∧ InWindow p r ∧ JurisdictionVerified r ∧
    r.scope = .newBuilding ∧ r.retainsExistingElements = false ∧
    r.specialConditions = false ∧ DocumentsPresent r ∧
    Grounded r.note r.scopeEvidence ∧ r.scopeReviewed = true

instance (p : Policy) (r : Request) : Decidable (Eligible p r) := by
  unfold Eligible
  infer_instance

inductive ReviewReason where
  | untrustedPolicy | outsideModelWindow | unsupportedJurisdiction | missingJurisdictionEvidence
  | unsupportedScope | retainedElements | specialConditions
  | missingIntakeFacts | ungroundedEvidence | unreviewedScope
  deriving DecidableEq, BEq, Repr

def reviewReason (p : Policy) (r : Request) : ReviewReason :=
  if p ≠ policyFor r.jurisdiction then .untrustedPolicy
  else if ¬ InWindow p r then .outsideModelWindow
  else if ¬ Supported r.jurisdiction then .unsupportedJurisdiction
  else if ¬ JurisdictionVerified r then .missingJurisdictionEvidence
  else if r.scope ≠ .newBuilding then .unsupportedScope
  else if r.retainsExistingElements ≠ false then .retainedElements
  else if r.specialConditions ≠ false then .specialConditions
  else if ¬ DocumentsPresent r then .missingIntakeFacts
  else if ¬ Grounded r.note r.scopeEvidence then .ungroundedEvidence
  else .unreviewedScope

inductive Decision where
  | routed : IntakeRoute → Decision
  | needsReview : ReviewReason → Decision
  deriving DecidableEq, BEq, Repr

def evaluate (p : Policy) (r : Request) : Decision :=
  if Eligible p r then
    match routeFor r.jurisdiction with
    | some destination => .routed destination
    | none => .needsReview .unsupportedJurisdiction
  else .needsReview (reviewReason p r)

theorem routed_requires_eligible (p : Policy) (r : Request) (destination : IntakeRoute)
    (h : evaluate p r = .routed destination) : Eligible p r := by
  unfold evaluate at h
  split at h
  · assumption
  · contradiction

theorem routed_uses_registered_policy (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : p = policyFor r.jurisdiction :=
  (routed_requires_eligible p r d h).1

theorem routed_within_model_window (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : InWindow p r :=
  (routed_requires_eligible p r d h).2.1

theorem routed_requires_jurisdiction (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : JurisdictionVerified r :=
  (routed_requires_eligible p r d h).2.2.1

theorem routed_requires_supported_scope (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : r.scope = .newBuilding :=
  (routed_requires_eligible p r d h).2.2.2.1

theorem routed_excludes_retained_elements (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : r.retainsExistingElements = false :=
  (routed_requires_eligible p r d h).2.2.2.2.1

theorem routed_excludes_special_conditions (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : r.specialConditions = false :=
  (routed_requires_eligible p r d h).2.2.2.2.2.1

theorem routed_requires_documents (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : DocumentsPresent r :=
  (routed_requires_eligible p r d h).2.2.2.2.2.2.1

theorem routed_requires_grounded_evidence (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : Grounded r.note r.scopeEvidence :=
  (routed_requires_eligible p r d h).2.2.2.2.2.2.2.1

theorem routed_requires_reviewed_scope (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : r.scopeReviewed = true :=
  (routed_requires_eligible p r d h).2.2.2.2.2.2.2.2

theorem routed_to_correct_jurisdiction (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : routeFor r.jurisdiction = some d := by
  have he := routed_requires_eligible p r d h
  simp [evaluate, he] at h
  cases hr : routeFor r.jurisdiction with
  | none => simp [hr] at h
  | some actual =>
    simp [hr] at h
    exact congrArg some h

theorem routed_requires_supported_jurisdiction (p : Policy) (r : Request) (d : IntakeRoute)
    (h : evaluate p r = .routed d) : Supported r.jurisdiction :=
  (routed_requires_jurisdiction p r d h).1

theorem mailing_address_alone_cannot_route (p : Policy) (r : Request)
    (hs : r.jurisdictionEvidence.source = .mailingAddressOnly) (d : IntakeRoute) :
    evaluate p r ≠ .routed d := by
  intro h
  have hc := (routed_requires_jurisdiction p r d h).2.1
  rw [hs] at hc
  contradiction

theorem ineligible_needs_review (p : Policy) (r : Request) (h : ¬ Eligible p r) :
    evaluate p r = .needsReview (reviewReason p r) := by
  simp [evaluate, h]

end CityPermitting
