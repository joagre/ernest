# A Publicly Verifiable Election

*Consolidated design record — 28 October 2026*
*Status: consolidated exploratory architecture, revised with bulletin-board, identity separation, cryptographic governance, election lifecycle, and dispute requirements; not a completed protocol or security proof*

## 0. Executive summary

The proposed system retains **supervised physical polling stations** but replaces paper ballots and manual counting with **private electronic ballot casting, automated cryptographic tallying, and a publicly verifiable election record**. Each polling station may operate an independently supervised network node that signs its local ballot record and **cross-witnesses** other stations' published evidence. Anyone—not just accredited auditors—may inspect the published data and run independent verification software.

The design deliberately accepts that **some human trust is unavoidable**, especially in voter eligibility checks, privacy inside polling stations, and the terminal's capture of voter intent. It seeks to reduce operational costs while replacing trust in computational counting and aggregation with publicly checkable evidence. Its costs and security benefits have not yet been quantified or demonstrated.

**Preferred distributed design:** polling-station nodes witness, replicate, check, and challenge one another's signed records; they do **not** collectively authorize every ballot or possess a discretionary veto over another station's legitimate votes. Consensus remains a possible response to a demonstrated threat, not a default requirement.

## 1. Why this design

The original distributed-election proposal explored remote voting, revoting to mitigate coercion, sophisticated cryptography, and a distributed network of authorities. A subsequent paper-first simplification retained manual counting and improved only publication and aggregation. That was judged too narrow: manual ballot handling and staffing can be major costs, although the actual cost breakdown must be measured.

The current proposal is a new synthesis:

- Keep polling stations and the practical privacy and human oversight they provide.
- Remove physical ballots and routine manual counting.
- Publish the complete *privacy-safe* electronic election evidence for unrestricted independent verification.
- Let polling-station nodes independently witness one another's records.
- Introduce cryptographic and distributed complexity only where it addresses a concrete risk or cost.

**KISS is a design discipline, not dogma.** Optimize total conceptual, technical, operational, and trust complexity—not the number of mechanisms in isolation.

## 2. Objectives and scope

1. Substantially reduce election operating costs, if evidence supports that outcome.
2. Preserve the familiar supervised, private polling-place voting experience.
3. Protect eligibility, uniqueness, ballot secrecy, and practical resistance to coercion.
4. Eliminate routine human ballot counting and enable verifiable automatic tallying.
5. Make the public election record, cryptographic proofs, software specifications, and verification procedures available to anyone.
6. Prevent undetectable alteration or equivocation in published station and national records, subject to explicit trust and availability assumptions.
7. Keep human and legal responsibility visible; cryptography does not decide contested eligibility or election law.

**Out of current scope:** remote voting, unlimited revoting, deniable credentials, credential recovery, a compulsory paper ballot, mandatory individual receipts, and a blockchain. These are not declared impossible or universally undesirable; they are unnecessary to the current candidate architecture.

## 3. End-to-end outline

```text
Eligible voter
     |
     v
Polling-station staff: eligibility and admission
     |
     v
Private voting terminal: electronic selection and encrypted ballot
     |
     v
Station node: authenticated local ballot log and signed checkpoints
     |
     +--------------------------+
     |                          |
     v                          v
Public bulletin board     Other station witness nodes
     |                    (verify, retain, cross-check,
     |                     publish conflicts)
     +--------------------------+
     |
     v
Public tally inputs + verifiable cryptographic tally proofs
     |
     v
National result, reproducible by independent verifiers
```

An **authenticated election configuration** defines the contest, eligible stations, applicable rules, public keys, and lifecycle before voting begins. The eligibility system and ballot system must be separated so that identity checks do not expose individual choices. A separately governed cryptographic trust structure supports the eventual tally.

The bulletin board is a **logical authenticated publication record**, not necessarily a blockchain, central trusted database, or Byzantine consensus system. Multiple independent mirrors can host and compare its evidence.

## 4. Trust model

| Boundary | Necessary trust or assumption | Independently checkable evidence |
|---|---|---|
| Registration | Correct eligibility decisions and voter register | Authorized roster rules, change logs, legal review |
| Polling staff | Genuine admissions, privacy, honest procedures | Participation reconciliation, witnessed station records, procedural objections |
| Voting terminal | It captures and encrypts the voter's actual intended choice | Source and build review, independent tests, operational checks; **not** guaranteed by tally proofs |
| Station node | Correct local recording and protection of signing keys | Signed ballot log, checkpoints, consistency proofs, cross-witness evidence |
| Bulletin board | Sufficient publication and access | Signatures, append-only consistency, mirrors, conflicting-record evidence |
| Tally authorities | Correct secret-key handling and protocol participation | Publicly verified tally proofs, subject to the selected cryptographic design |
| Election/legal authorities | Legitimate dispute and finality decisions | Published decisions, corrections, and procedural evidence |

The system cannot make a false initial input true. If a terminal displays A but encrypts B, a valid public tally can still be **correctly computed from the wrong input**. This is an explicit engineering trust boundary, not a solved cryptographic property.

## 5. Security and public-trust requirements

- **Eligibility:** only eligible persons can contribute counted votes.
- **Uniqueness:** no more than one vote per eligible person contributes to the final tally.
- **Completeness:** each valid, completed voting event contributes a ballot, subject to clearly defined cancellation and recovery rules.
- **Secrecy:** the public record must not disclose individual choices or identify voters from their encrypted ballots.
- **Practical coercion resistance:** private supervised casting should offer protection comparable to conventional polling-place voting. No protocol can prevent kidnapping, physical confinement, or uninterrupted surveillance; absolute coercion resistance is not required.
- **Public verifiability:** anyone can check the cryptographic validity of the accepted ballot set and tally, within the guarantees of the final protocol.
- **Publication consistency:** conflicting signed histories are detectable and can be presented as evidence.
- **Availability and recovery:** terminal or network failure must not silently disenfranchise voters; safe procedures are needed for offline operation, interruption, and restart.
- **Public accountability:** cryptographic failures, disputes, corrections, and finality decisions are not silently concealed.

A distinction must be maintained between **ballot secrecy**, **receipt-freeness**, and **coercion resistance**. They are related but not equivalent.

## 6. The voter experience and the receipt decision

1. The voter arrives at a supervised polling station and is checked for eligibility.
2. A voting session is authorized without exposing voter identity in the published ballot record.
3. The voter privately selects a candidate or option on an electronic terminal.
4. The terminal records an encrypted ballot through the station's authenticated admission and recording process.
5. The public record later supports independent verification of tally processing.

**A paper receipt is not currently required.** The earlier receipt proposal was intended to let a voter find their own ballot and check inclusion. Publishing all ballots and proofs allows **public tally verification**, but does **not automatically give an individual voter evidence that their own ballot was included**. This is a deliberate unresolved trade-off, not a property obtained for free by transparency. If individual inclusion verification is later required, a privacy-preserving mechanism must be specified and assessed for vote buying and coercion risks.

## 7. Public evidence and verification

Publish everything that can safely be disclosed **without compromising voter secrecy or protected credentials**. Candidate categories include:

- Election definition, eligible ballot formats, station roster, and applicable public rules.
- Accepted encrypted ballots or their protocol-defined public representations.
- Signed station records, checkpoints, commitments, and consistency evidence.
- Reconciliation summaries between authorized voting events and accepted ballots, without exposing voter-to-choice links.
- Tally inputs, cryptographic proofs, result calculations, and verifier specifications.
- Relevant software source, build information, test results, incidents, objections, correction chains, and legal decisions.

Any person or organization may mirror evidence, write a verifier, run checks, and publish discrepancies. **Public availability is not the same as public correctness**: completeness of admission and faithful capture of voter intent need separate controls.

### What independent checking can and cannot show

| Claim | Status |
|---|---|
| A published record has valid signatures and has not been altered unnoticed | Checkable with suitable key and log design |
| Published encrypted ballots were processed according to the specified tally protocol | Checkable if the chosen protocol supplies sound public proofs |
| A ballot was not duplicated within the accepted tally set | Checkable if uniqueness is explicitly proven in that protocol |
| Every accepted ballot originated from a legitimate voter | **Not established** by encryption or signatures alone |
| Every legitimate completed voting event appears in the record | **Not established** without admission/reconciliation evidence and assumptions |
| The terminal encoded the choice the voter intended | **Not established** by public tally proofs |
| No voter was coerced | Not establishable from election records alone |

## 8. Public bulletin board — first-class architectural component

The **public bulletin board** is the logical, publicly readable and authenticated record of the election. It is **not** a separate authority that decides which votes count, and need not be a single server, blockchain, or globally synchronized database. Polling-station nodes produce and cross-witness evidence; independent mirrors publish and preserve it; anyone may retrieve it and verify the election. The board is the interface between election operations and public accountability.

### Required properties

1. **Publicly readable:** all privacy-safe election evidence, proofs, and verification specifications are available to everyone, without requiring auditor accreditation.
2. **Authenticated:** every critical publication has a verifiable origin, including election configuration, station checkpoints, ballot-set commitments, corrections, disputes, and final results.
3. **Append-only and historically accountable:** corrections and supersessions are new, linked publications; original records and objections remain visible.
4. **Consistent or detectably inconsistent:** stations and independent mirrors compare signed checkpoints and retain conflicting histories as independently checkable evidence. A signature alone does not guarantee a single history.
5. **Complete under explicit closing rules:** the final accepted record must account for every authorized station and its finalized local record, with missing, disputed, and excluded records explicitly identified. **How this completeness is established remains an open protocol problem.**
6. **Independently reproducible:** published inputs and sound cryptographic proofs must allow anyone to verify the tally and reproduce the published result, subject to the protocol's stated assumptions.
7. **Privacy-preserving:** publication must not expose voter-to-ballot links, protected credentials, or identifying metadata; publishing encrypted ballots is not automatically safe against correlation or future cryptanalytic risks.
8. **Recoverable and accessible:** independent copies and clearly specified outage, synchronization, and finalization procedures prevent a single publishing service from being an indispensable point of failure.

### Relationship to the polling-station network

Each station owns and signs its local evidence. Other stations **witness, check, retain, and challenge** that evidence; they do not obtain discretionary veto power over otherwise legitimate station records. The bulletin board exposes both the records and the challenges. Different nodes need not have identical local databases at every instant, but the protocol must establish an auditable, final election view or explicitly report that finality has not been reached.

A malicious station can publish a self-consistent but fraudulent local record; cryptographic witnesses cannot establish that voters actually appeared. Conversely, a publisher can omit an honest station unless the finalization rules and independently retained station evidence make that omission detectable. **Cross-witnessing is therefore not a substitute for ballot-admission controls, reconciliation, or a closing-and-completeness protocol.**

### Open bulletin-board protocol questions

- What precisely constitutes a station's final signed record, and how are late ballots, interruptions, and corrections handled?
- Who establishes the authorized station roster, and how can the public detect omitted stations and omitted accepted ballots?
- What evidence proves append-only evolution and exposes equivocation across independent mirrors?
- When may the national tally be declared final if a station is offline, compromised, or under legal dispute?
- How are publication timing and metadata handled without compromising ballot secrecy?

The board is **part of the core architecture**, not a separate optional project. Detailed data formats, checkpoint protocols, consistency proofs, and finality rules can later be specified in dedicated technical documents.

## 9. Polling-station witness network — preferred candidate

Each station operates an independently supervised node. Its personnel oversee the local physical voting process; its node maintains and signs the electronic record. Nodes **witness and verify one another** rather than voting on whether each ballot may exist.

### Responsibilities

1. Maintain an append-only local record of accepted encrypted ballots and defined voting-session events.
2. Periodically issue signed checkpoints containing station identity, election identity, sequence position, ballot count, and a cryptographic commitment to the local record.
3. Disseminate checkpoints and necessary proofs to other station nodes and public mirrors.
4. Verify received signatures, protocol constraints, cryptographic proofs, and append-only consistency.
5. Preserve and publish conflicting signed histories, invalid proofs, and unresolved discrepancies as evidence.
6. Continue or recover under explicit network-outage rules, with no silent deletion or rewriting of evidence.

### Why witnessing rather than collective authorization?

Remote stations can verify **digital evidence**, but they cannot personally confirm whether a voter appeared at another station. Granting them approval or veto power over every ballot could add consensus complexity, latency, network dependence, and the ability of a malicious coalition to obstruct legitimate votes without solving dishonest local admission.

**Preferred rule:** a station's eligible, validly authenticated record enters the national tally according to **public acceptance and dispute rules**, not discretionary approval by other stations. A remote station may challenge a record with evidence, but may not suppress it merely by refusing to cooperate.

**Neither majority approval nor cross-witnessing alone proves local honesty.** Cross-witnessing primarily helps detect inconsistent publication, tampering after publication, and some protocol violations. Independent witnesses must actually receive and retain evidence for equivocation to be detectable; offline or colluding witnesses reduce that assurance. A concrete append-only proof, checkpoint dissemination, and gossip/mirror design remain to be specified.

Collective authorization or consensus may be revisited **only** if the threat analysis demonstrates a specific failure that witnessing cannot adequately address.

## 10. Identity–ballot separation — first-class architectural boundary

The **eligibility system** establishes who may participate and whether a voting entitlement has been exercised. The **ballot system** accepts and processes encrypted choices without learning the voter’s identity. Their cooperation must not produce a durable identity-to-ballot mapping.

A candidate workflow is that staff authenticate a voter and authorize one anonymous voting session; the terminal consumes that authorization and produces an encrypted ballot; the station accounts for the authorization and accepted ballot without retaining a link between identity and choice. **This is a candidate, not a specified secure protocol.** Session tokens, timestamps, terminal assignment, ordering, network traffic, support logs, and public publication metadata can re-identify voters even if ballot payloads are encrypted. Privacy analysis must include collusion among station staff, terminal operators, registration authorities, and network observers.

Required properties to investigate: eligible admission, single counted ballot, reconciliation of completed sessions and accepted ballots, recovery from interruption, and non-linkability under a stated adversary model. Public aggregate counts alone cannot prove that local officials did not collude to create fraudulent admissions.

## 11. Cryptographic trust and key custody — first-class architectural component

Encrypted ballots and public tally proofs do not by themselves specify who can decrypt, sign, substitute, or suppress evidence. The design must assign each cryptographic power explicitly: station signing, election configuration authorization, ballot encryption, tally/decryption, and verification. These powers should not silently collapse into one administrator or key.

Investigate independently controlled key custodians and threshold operations where justified. Specify key generation, public-key certification, custody, backup, rotation, loss, compromise, and end-of-election handling. Decide whether the tally protocol reveals only aggregate totals or any decrypted individual ballots, and define the secrecy assumptions accordingly. **Threshold cryptography is a candidate control, not yet an architectural decision.**

Anyone should be able to check the proofs using published verification keys and rules. Independent verifiability must not depend on possession of tally secrets.

## 12. Authenticated election configuration and lifecycle

The election begins with an authenticated, publicly inspectable configuration defining at least the contest and candidates, ballot encoding, eligibility and constituency rules, station roster and public keys, cryptographic parameters, publication and acceptance rules, opening/closing conditions, and the authority to make lawful changes.

The lifecycle needs explicit states and transitions: preparation, authorization, opening, casting, closing, reconciliation, tallying, challenges, correction, and finalization. Changes to configuration must be versioned, signed, published, and subject to clear timing and legal rules. A cryptographically valid tally of ballots under an unauthorized or altered configuration is not a valid election result.

A **finalization/completeness protocol** remains unresolved. Signed station closures, expected-station reconciliation, accepted-ballot commitments, challenge periods, and public evidence of omissions are candidate ingredients; cross-witnessing alone does not establish completeness or legal finality.

## 13. Disputes, correction, and recovery — cross-cutting responsibility

Every stage needs a defined failure and challenge path. The public record must preserve the original signed evidence, subsequent objections, authorized corrections, and final decisions rather than silently replacing history. Any observer may submit verifiable technical evidence; designated lawful authorities must decide contested physical facts and remedies under published rules.

Specify who can dispute a station or tally, what evidence is admissible, who decides, how conflicts of interest are handled, how a correction affects the tally, and when a result becomes legally final. Define safe procedures for terminal failure, station disconnection, missing keys, disputed ballots, compromised station signatures, and conflicting bulletin-board views. **Detection is not a remedy**: a complete design must say what happens after a failure is detected.

The bulletin board publishes evidence and decisions; it does not independently determine legal truth.

## 14. Preliminary adversarial review

| Threat | Failure mode | Candidate mitigation or accepted limit |
|---|---|---|
| Malicious terminal | Displays A, encrypts B | Simple inspectable engineering, independent testing, challenge/audit techniques where justified; residual trust acknowledged |
| Fraudulent admission | Extra validly encrypted ballots | Human supervision and reconciliation of eligible participation with accepted ballots; collusion remains a threat |
| Ballot omission | A completed vote is absent | Signed local events, reconciliation, witnesses, explicit dispute and recovery rules |
| Double counting | A ballot appears twice or more | Protocol-level uniqueness checks and publicly verifiable tally construction |
| Bulletin-board equivocation | Different audiences see different histories | Signed checkpoints, independent mirrors, cross-witnessing, public conflict evidence |
| Witness outage or collusion | Missing evidence or delayed publication | Replication diversity, recovery rules, explicit availability and trust thresholds |
| Dishonest tally | Wrong result from published ballots | Public cryptographic tally proofs |
| Key compromise | Ballot secrecy or signing authenticity fails | Key separation, distributed control where justified, rotation and incident procedures |
| Terminal/network outage | Voters cannot complete voting | Spare equipment, interruption recovery, operational contingency procedures |
| Coercer outside booth | Pressure or attempted vote buying | Private supervised casting; no receipt proving choice; legal/social controls remain necessary |

These are hypotheses and candidate controls, **not completed proofs**.

## 15. Main unsolved design problems

### 15.1 Ballot admission and uniqueness

> Every counted ballot must originate from one authorized voting event; every valid, completed voting event must contribute exactly one ballot; and the public should be able to verify the required correspondence without learning the voter's choice.

This must handle duplicate attempts, abandoned sessions, terminal crashes, cancellations, provisional votes, and disputed admission. Public reconciliation may establish aggregate equality without establishing the honesty of colluding local personnel. The exact security claim must reflect that limit.

### 15.2 Complete, consistent publication

Define a signed append-only record, checkpoint consistency proofs, independent mirrors, dissemination guarantees, and behavior under partitions or contradictory histories. Detecting equivocation is not identical to preventing it or guaranteeing timely publication.

### 15.3 Private, publicly verifiable tally

Select and analyze a protocol (for example, homomorphic tallying or a verifiable mix-and-decrypt design). Establish precise privacy, correctness, uniqueness, key-compromise, and proof-verification assumptions before selecting algorithms.

### 15.4 Voting-terminal integrity

Engineer a small, inspectable, independently tested terminal and trustworthy operational procedures. Decide whether probabilistic challenge mechanisms materially improve the risk profile. Do not claim the terminal is proven faithful merely because its outputs are cryptographically well formed.

### 15.5 Governance, legal finality, and recovery

Specify who may declare a station record disputed, how evidence is adjudicated, how corrections are published without rewriting history, when results become final, and how the election continues through equipment and network failures.

### 15.6 Real cost and usability

Measure conventional costs and compare against terminal procurement, maintenance, replacement, security reviews, training, accessibility, connectivity, incident handling, and cryptographic infrastructure. **Lower total cost is a goal to test, not an established result.**

## 16. Decisions reached on 28 October 2026

| Subject | Current position |
|---|---|
| Polling stations | **Retain** supervised physical stations |
| Ballot medium | **Electronic**; no routine paper ballot |
| Counting | **Automated**, with publicly checkable proofs |
| Public evidence | Publish all privacy-safe election evidence |
| Bulletin board | **Core logical public record**: authenticated, append-only, mirrored, independently verifiable; final completeness remains unresolved |
| Independent auditors | **Anyone** may verify; no exclusive auditor class |
| Human trust | Explicitly accept necessary trust in polling staff and terminal |
| Coercion | Seek practical protection comparable to supervised paper voting; no absolute guarantee |
| Individual receipt | **Not required**; individual inclusion verification remains an explicit trade-off |
| Remote voting/revoting | **Not part of this architecture** |
| Polling-station nodes | **Preferred candidate** for signed local records and cross-witnessing |
| Collective node approval | **Not required** for each ballot; no remote discretionary veto |
| Blockchain or global consensus | **Not required**; revisit only for a demonstrated need |
| Identity–ballot separation | **Core architectural boundary**; concrete anonymous admission protocol unresolved |
| Cryptographic key custody | **Core responsibility**; independent or threshold custodianship to be evaluated |
| Election configuration/lifecycle | **Authenticated and publicly versioned**; finalization and completeness rules unresolved |
| Disputes and recovery | **Cross-cutting requirement**; public evidence, corrections, legal decisions, and remedies |
| Tally cryptography | **Open** pending protocol and threat analysis |
| Security completeness | **Not claimed**; key obligations remain unresolved |

## 17. Next work session

Start with **ballot admission and identity–ballot separation**, under an authenticated election configuration. Write a minimal state machine for eligibility checking, session authorization, ballot acceptance, completion, cancellation, and recovery. State exactly what local officials attest, what the station node signs, and what independent verifiers can prove. Then attack it with forged admissions, omitted votes, duplicate sessions, compromised terminals, and colluding staff. Only afterward select cryptographic primitives and network protocols.

## Governing principle

> **Trust humans where human judgment is unavoidable. Demand publicly verifiable evidence wherever computation can replace trust.**

Transparency should expose the evidence and the limits of that evidence. Complexity is justified by measurable operational benefit or a specific security guarantee—not by elegance, novelty, or a desire to eliminate every imaginable threat.
