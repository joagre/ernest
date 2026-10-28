# Fides: A Publicly Verifiable Election

**Consolidated design paper — Version 9.1 — 28 October 2026**
**Status:** Exploratory architecture and requirements. Decisions, preferred candidates, assumptions, and unresolved obligations are distinguished throughout. This is **not** a completed voting protocol, implementation specification, security proof, or claim of legal compliance.

## Abstract

Fides proposes supervised, in-person electronic voting at independent offline polling stations, with encrypted ballots, homomorphic tallying, and publicly checkable election evidence. Station nodes admit ballots under identified local voting sessions, commit accepted ballots durably, and export signed records for independent publication and audit. Every committed ballot generates a signed acceptance statement that can be issued as a QR-coded receipt; voters may decline or lose the receipt without invalidating their ballot.

The design deliberately separates human trust from mathematical verification. Polling officials establish real-world eligibility; independently tested terminals are trusted to capture voter intent; cryptography protects ballot secrecy and enables anyone to verify the tally of published accepted ballots. Fides **does not claim full end-to-end verifiability**, because its initial protocol has no independent cryptographic cast-as-intended verification. Public evidence alone also cannot prove that every real voter was authorized honestly or that every unobserved station event was published.

Ballot admission uses two linked state machines—voter entitlement and individual voting session—with atomic, durable commit and cancellation, safe retries, and reauthorization after a genuinely cancelled attempt. Publication completeness is supported by independently preserved signed closing commitments, voter receipts, and genuinely independent participation reconciliation; none is an unconditional proof of completeness. Five independently governed trustees with a **3-of-5 threshold** are now an architectural decision; threshold exponential ElGamal and a compatible reviewed distributed key generation protocol remain preferred constructions requiring exact instantiation and review.

**Status:** Exploratory architecture and protocol requirements, not a deployed implementation, security proof, or legal certification. Trustee threat boundaries, manifest finality, and the first integrated adversarial review (publication, duplication, receipts and privacy) have been examined at the architectural level. Exact cryptographic selection and further whole-system adversarial analysis remain open.

## 1. Purpose and design discipline

Fides aims to reduce the operational burden of elections while retaining supervised physical polling stations and strengthening public scrutiny of results. Whether it actually reduces costs, and by how much, must be established empirically; electronic equipment, maintenance, security reviews, logistics, and incident handling have costs of their own.

The governing principle is:

> Trust people where human judgment is unavoidable. Demand publicly verifiable evidence wherever computation can replace trust.

A complementary principle is **cryptographic minimalism**: prefer established, independently reviewed mechanisms with the smallest practical *total* complexity. A new mechanism must earn its place by satisfying an explicit requirement. Simplicity is not an excuse to omit a necessary safeguard, nor is theoretical resilience a reason to add unbounded machinery.

Fides does **not** seek perfect anonymity, immunity to unlimited collusion, absolute coercion resistance, or guaranteed completion under every emergency. It seeks defensible guarantees under a stated threat model and conspicuous failure rather than an unverifiable result.

## 2. Scope and baseline election

The initial protocol targets a single election with:

- One eligible voter casting at most one counted ballot.
- One selection from a fixed candidate or option list; more complex ballots are deferred.
- Supervised, private, in-person voting at an assigned polling station.
- A pre-established, authenticated electoral roll partitioned by station.
- Electronic ballots; no routine paper ballots or manual counting.
- A station-local Fides node and locally connected voting terminals, operable without external connectivity during voting.
- Publicly verifiable encrypted tallying and a privacy-safe election record.
- A legally authorized election authority, independent decryption trustees, and public witnesses.

Remote voting, unrestricted voting at any station, revoting, deniable credentials, mix-net tallying, blockchain consensus, and mid-election reconfiguration are outside the initial protocol. Exceptions such as absentee voting, provisional ballots, inaccessible stations, and legal recount procedures require separate consideration before real-world deployment.

The paper states **requirements** for nodes and terminals, not their hardware or engineering design. Tablets, cables, operating systems, databases, storage media, backup techniques, and physical construction are implementation choices. The earlier idea of wired iPads is one possible realization, not a protocol requirement.

## 3. System roles and trust boundaries

**Election authority.** Legally defines the election, authorizes the station roster and electoral rolls, signs the canonical election manifest, and governs exceptional decisions. Its legal legitimacy is external to cryptography.

**Polling-station personnel.** Authenticate voters, enforce privacy and physical procedures, supervise voting, attest to legitimate authorizations, handle incidents, and participate in reconciliation. Fides necessarily trusts them to a limited extent. Fraudulent real-world participation cannot be disproved by cryptographic signatures alone.

**Voting terminal.** Privately presents choices and prepares a correctly formed encrypted ballot. Its faithful capture of voter intent is a critical trust boundary. Tally proofs do not establish that a terminal encrypted the option the voter intended.

**Fides station node.** Enforces station-local authorization and ballot-admission rules, maintains durable authenticated evidence, signs records and closing statements, and exports public evidence. Its internal records must not reveal plaintext choices; compromises and failures must be bounded and made evident where feasible.

**Trustees.** Jointly control decryption authority. Their primary secrecy obligation is not to decrypt individual ballots; their availability obligation is to supply verifiable partial decryptions of authorized aggregates. Ordinary threshold encryption cannot cryptographically stop a sufficient colluding threshold from decrypting individual ciphertexts.

**Public bulletin board and witnesses.** Publish, mirror, preserve, compare, and challenge signed evidence. Witnesses do not authorize individual ballots or possess a veto over legitimate station records. Anyone may act as an independent verifier.

**Voters.** Cast ballots privately and may optionally retain signed acceptance receipts to verify that their accepted encrypted ballot was published.

The distinctions between *physical*, *administrative*, *logical*, and *cryptographic* separation are important. Different services on one compromised node do not automatically constitute independent trust domains.

## 4. Security objectives and limits

1. **Eligibility.** Every counted ballot must arise from an authorized voting event, supported by eligibility procedures and auditable authorization evidence.
2. **Uniqueness.** At most one accepted ballot may result from each authorized voter under the initial station-assignment rules.
3. **Completeness.** Every validly committed ballot must be represented in the published accepted-ballot set, or an explicit, publicly accountable failure must be declared.
4. **Ballot secrecy.** Station personnel must not learn a voter's selection from ordinary protocol records, even if they can associate the voter with an encrypted ballot. The result must not disclose individual selections.
5. **Practical polling-place privacy.** Physical procedures must provide protection broadly comparable to supervised paper voting. Neither paper nor Fides can prevent every conceivable collusive or physical attack.
6. **Cast-as-intended.** Terminals must faithfully represent and encrypt voters' selections. This remains an engineering and assurance requirement, **not a property proved by the tally protocol**.
7. **Recorded-as-cast.** An accepted encrypted ballot must be durably recorded and publicly represented; signed acceptance statements, optionally retained by voters, help detect omissions or substitutions.
8. **Tallied-as-recorded.** Anyone must be able to check that the published result follows from exactly the published accepted, valid encrypted ballots and sound decryption proofs.
9. **Public accountability.** Signed contradictions, missing evidence, unresolved discrepancies, and exceptional legal decisions must be visible rather than silently repaired.
10. **Fail-safe operation.** Exceptional failures may invalidate an election. Fides need not preserve availability at the cost of integrity or secrecy.

**Secrecy is not unlinkability.** The initial design does not promise that a station cannot associate a voter with a ciphertext. It relies on secure randomized encryption, threshold key custody, and decryption of aggregates only. This creates a residual risk if decryption keys are later compromised, a threshold colludes, or operational records are copied. Identity-to-ciphertext associations should therefore be minimized, access-controlled, and discarded when no longer necessary, subject to law and audit requirements. The paper must not promise that deletion erases previously observed or copied associations.

Likewise, secrecy, receipt-freeness, and coercion resistance are distinct properties. Receipts must not contain a candidate choice or encryption randomness; nevertheless Fides does not guarantee receipt-freeness or coercion resistance against compromised terminals, trustee collusion, or coercive disclosure of other evidence.

## 5. Authenticated election manifest and finality

**Decision:** Each election is governed by exactly one canonical, digitally signed, *finally committed* election manifest issued by the legally authorized election authority. It defines:

- A unique election identifier, protocol version, ballot and counting rules, and canonical candidate or option identifiers and ordering.
- Authorized voting dates and opening/closing conditions.
- The roster of assigned polling stations, their identifiers and certified signing keys, and relevant station-assignment rules.
- The election public encryption key, trustee identities and certified public-share information, cryptographic parameters, and proof-verification rules.
- The rules for authenticated evidence export, exceptional suspension, and finalization.

Canonical encoding must be specified so that all compliant verifiers derive the same manifest hash, `h_M`. Ballots, validity proofs, receipts, opening and closing records, station exports, and tally evidence are bound to `h_M` using unambiguous domain separation. The election authority's verification key must come from a **pre-established authenticated trust anchor**, not from the untrusted manifest package itself.

### 5.1 Authenticity is not unique authority

A valid authority signature proves that the corresponding key signed the document. It does **not** prove freshness, that no other signed manifest exists, or that the signer acted with legitimate legal authority. Two conflicting, correctly signed manifests can both verify. A preliminary signed manifest may also be replayed after a later revision.

Before voting, the legally defined finalization procedure must establish **one final manifest hash** and make that commitment publicly observable and independently preserved. Multiple independently controlled channels or witnesses should preserve evidence of the same final hash; merely supplying the hash on the same removable medium as the manifest is not independent confirmation. The legal procedure, not a blockchain or consensus protocol, determines which commitment is authoritative. If two conflicting final commitments are discovered, signature verification cannot decide which one is legitimate: the conflict must be resolved through the authorized procedure **before opening**.

### 5.2 Offline station opening

Manifest distribution may use untrusted offline media. Before opening, each station verifies both the authority signature and the **exact final hash** against independently authenticated opening evidence. Its signed opening statement identifies `h_M`. No external connection is needed during voting, and the bulletin board is not the sole source of the authoritative hash. Independent public verifiers likewise require access to the final commitment independently of the bulletin board they inspect.

### 5.3 Immutability and exceptional failures

Once voting begins, the manifest is frozen. A station must not silently switch candidate ordering, election keys, authorized station lists, or counting rules. A serious error, compromised signing key, conflicting final commitment, or attempted replacement after opening can require suspension, invalidation, or a fresh election with a new identifier and manifest. Existing signed evidence must be preserved. There is no ordinary hot-update or online revocation service in Fides v1.

A compromised terminal can still display labels inconsistent with the authenticated manifest while encrypting formally valid ballots. Manifest binding does not solve cast-as-intended assurance (§12). Similarly, a stolen legitimate station signing key can forge apparently authentic station records; the roster limits authorized identities but does not prove their keys remained uncompromised.

## 6. Station architecture and voting experience

Each station has a locally authoritative Fides node and one or more private voting terminals. During the voting period, it need not communicate with the Internet, the election authority, trustees, other stations, or the bulletin board. Local authorization, ballot acceptance, and durability are therefore independent of external network availability.

The intended voter experience is:

1. An official checks the voter against the station's authenticated electoral roll.
2. The station creates or resumes one authorized local voting session.
3. The voter privately selects an option on a terminal.
4. The terminal prepares a randomized encrypted ballot and the required validity proof.
5. The station accepts the ballot through a durable, single-commit operation; an accepted session cannot produce another ballot.
6. A receipt may be printed after acceptance, and the voter leaves.
7. After closing, authenticated station evidence is exported, witnessed, and published for public verification.

**Fixed station assignment** is an initial assumption that allows offline uniqueness without a national real-time spent-credential service. A person must not be independently authorized to vote at two stations. Allocation and exceptional transfers must be handled by the electoral roll and election procedures before voting, or through a separately specified exception protocol.

A single local node is an availability concentration: failure or irrecoverable loss can affect its station. The protocol requires durable recovery and explicit incident procedures but does not prescribe redundant hardware or continuous replication. The consequences of catastrophic failure must be stated honestly.

## 7. Ballot admission, cancellation, and crash recovery

**Decision:** Fides uses identified station-local voting sessions, not blind signatures or anonymous credentials. The station may temporarily associate voter identity, session, and ciphertext to enforce uniqueness and recover interrupted sessions; that association is excluded from public ballot records and minimized in retained private records.

### 7.1 Two distinct state machines

A voter entitlement and an authorization *attempt* are different objects. A voter may abandon and cancel an attempt without forfeiting the right to vote. Accordingly, a cancelled session is terminal, but a voter may receive a new session if no ballot was committed.

| Voter entitlement | Meaning |
|---|---|
| `NotVoted` | No active session and no committed ballot; may be authorized |
| `Voting(session_id)` | Exactly one active authorization attempt |
| `Voted` | Exactly one ballot committed; no further authorization permitted |

| Session state | Meaning |
|---|---|
| `Active` | May commit one ballot or be cancelled |
| `Committed(ballot_ref)` | Terminal; exactly one durably accepted ballot |
| `Cancelled` | Terminal; no ballot accepted; cannot be revived |

An eligible voter moves atomically from `NotVoted` to `Voting(s)` when a new active session is created. A successful commit atomically moves `Voting(s)` to `Voted` and `Active(s)` to `Committed(b)`. Cancellation atomically moves `Voting(s)` to `NotVoted` and `Active(s)` to `Cancelled`. A previously cancelled session is never reopened; a later attempt receives a fresh session identifier. A committed vote is never overwritten or cancelled to permit another ballot.

### 7.2 Single durable commit point

The station node—not the terminal—is authoritative for session state. A terminal submits a prepared encrypted ballot and its validity proof under the active session. The node verifies the session, manifest binding, ciphertext, and proof, then **atomically and durably** (i) stores the accepted ballot and its acceptance evidence, (ii) records the session as committed, and (iii) marks the voter entitlement as voted. Either all these effects become durable or none do. The node acknowledges acceptance and signs or releases a receipt only **after** this commit point.

The protocol requires these observable guarantees, not a particular database, filesystem, or hardware implementation. A durable accepted ballot must remain available for authenticated export; an asynchronous publication queue may be used only if it cannot lose a committed ballot without detectable failure.

### 7.3 Retry, cancellation, and recovery rules

- **Before commit:** a crashed terminal or interrupted submission leaves an active session recoverable. A voter may resume or, after a conclusively successful cancellation, start a fresh session. A newly used terminal must not expose the previous voter's selection.
- **After commit:** loss of the acknowledgement does not undo acceptance. On retry, the node returns the existing acceptance status and reference; it does not accept another ballot.
- **Identical retry:** the already committed result may be returned without adding a ballot. **Different submission:** it must be rejected once a session is committed, even if the voter believes the first attempt failed.
- **Concurrent cancellation and commit:** the node serializes both against the same authoritative state. Exactly one wins. Cancellation after commitment fails; commitment after cancellation fails.
- **Printer failure or receipt loss:** neither invalidates the committed vote. Reissuance may be supported while the protected session-to-ballot reference is still retained.
- **Abandonment:** an active session cannot simply be *declared* cancelled while a pending commit might still succeed. Cancellation must be durably completed, and any stale terminal capability must be unable to commit afterward.
- **Station close:** all active sessions must be resolved as committed or cancelled, or disclosed as unresolved exceptions. A station must not silently classify an ambiguous attempt as cancelled.

The two principal safety invariants are (1) at most one committed ballot per voter entitlement, and (2) at most one accepted ballot per session. These hold only if the node correctly enforces durable atomic transitions and the assigned electoral roll prevents parallel authorization at another station. Catastrophic loss of authoritative durable state may require suspension or invalidation rather than speculative reconstruction.

### 7.4 Authorization accounting

Let `E` be the number of issued **session attempts**, `A` the number committed, and `C` the number durably cancelled. At a fully resolved close, `E = A + C`. This is an **attempt** equation, not a count of unique voters: one voter may have multiple cancelled attempts before one committed vote. Separate figures are needed for unique participating voters, committed ballots, cancelled attempts, and any unresolved attempts. The number of committed ballots must reconcile with independently established completed-voting events, under a specified procedure.

Balanced counts can be fabricated by dishonest personnel or a compromised node. Neither a signed equation nor a cryptographically valid ballot proves that a real eligible person appeared.

### 7.5 Private association and retention

A station may need a protected voter–session–ballot association for retries, disputes, and receipt reissuance. Public ballot evidence must omit identity and session identifiers. The association should be discarded when operational, audit, and legal needs permit, with an explicit retention policy. Deletion cannot undo copies already made, and the secrecy model assumes trustees do not misuse their threshold decryption capability.

### Why blind signatures were set aside

Blind-signed tokens obscure issuance-to-redemption linkage but make targeted cancellation and lost-token recovery harder. Since Fides accepts temporary identity-to-ciphertext association while requiring plaintext secrecy, the added anonymous-credential machinery is not justified for the initial protocol.

## 8. Cryptographic ballot and tally — preferred candidate

For the initial single-choice ballot, the leading construction is **threshold exponential ElGamal with additive homomorphic aggregation**. The exact group, encoding, proof system, domain separation, and bounds remain to be specified and reviewed.

At a high level:

1. The terminal encrypts the choice under the manifest's public election key, using fresh randomness.
2. It supplies a zero-knowledge proof that the encrypted selection is well-formed and represents exactly one permitted choice. The proof must be bound to the election manifest and ballot definition.
3. The station accepts only ballots whose required proofs verify and whose authorizations satisfy the admission rules.
4. Published accepted ciphertexts are aggregated homomorphically to obtain encrypted candidate totals.
5. Trustees provide verifiable partial decryptions of **aggregate totals only**.
6. Anyone can reconstruct the aggregation, verify the proofs, and verify the published totals.

The proof construction must rule out malformed ballots, invalid candidate encodings, and ballot duplication under the chosen admission rules. Tally arithmetic must respect explicit election-size bounds and ensure totals are unambiguous. Small aggregate reporting groups can leak individual choices; Fides should not routinely publish decrypted station-level totals. Public disclosure of individual plaintext ballots is outside the design.

**Why not mix-nets?** Verifiable shuffling and its proofs introduce complexity not yet justified by the initial fixed-choice, aggregate-tally requirements. A mix-net remains an alternative if later election types or privacy requirements demand it.

**Important limit:** A cryptographically correct tally can faithfully count ballots that a compromised terminal misrepresented or a dishonest official fraudulently admitted. Public tally proofs do not establish real-world eligibility or cast-as-intended behavior.

## 9. Trustees, key generation, and key custody

**Architectural decision:** Fides uses **five independently governed trustees with a 3-of-5 decryption threshold**. They participate in election setup and aggregate tally decryption, but are not needed while stations accept votes. The choice balances separation of control against availability and ceremony complexity; organizational independence matters as much as the numerical count.

### 9.1 The precise security boundary

Under a suitable secure threshold construction, **fewer than three colluding trustees cannot decrypt** a ciphertext using their shares. **Any three trustees with valid shares can decrypt** an aggregate ciphertext and, technically, **can also decrypt an individual published ballot**. Aggregate-only decryption is therefore a required authorized *procedure*, not a restriction enforced by the underlying threshold mathematics. Three trustees may secretly violate ballot secrecy, potentially without producing publicly detectable evidence. Operational separation, share protection, oversight, and minimizing voter–ciphertext associations reduce risk but do not eliminate this collusion boundary.

Conversely, trustees cannot make an **incorrect tally pass sound public verification** simply by supplying false partial decryptions. Each accepted partial decryption must have a publicly checkable proof bound to the exact aggregate ciphertext and the trustee's certified public share. Verifiers reject malformed or invalid contributions and independently reconstruct the combined result. This guarantee is conditional on correct cryptographic construction, proofs, implementation, and the authenticated set of ballots; it does not repair dishonest ballot admission.

### 9.2 Availability and refusal

Any three valid, available trustees suffice for authorized aggregate decryption. Two unavailable trustees can be tolerated; if fewer than three valid shares remain available, decryption cannot complete. A malicious trustee may withhold a share or supply an invalid proof; an available replacement trustee can contribute instead. If a threshold cannot be reached, Fides **does not publish an unverifiable tally**. Failure to finalize may require the legally prescribed exceptional remedy.

### 9.3 Distributed key generation

**Preferred cryptographic construction:** a well-reviewed, malicious-participant-aware distributed key-generation (DKG) protocol compatible with the selected threshold exponential ElGamal scheme, ballot-validity proofs, and threshold-decryption proofs. The private election key must not be assembled by any honest participant. Trustees obtain verifiable shares; the election public key, share-verification keys, parameters, and relevant setup evidence must be authenticated and bound to the final manifest.

The actual DKG must define authenticated communication, participant qualification, invalid contributions, complaints, abort conditions, and publicly checkable evidence as appropriate. A 3-of-5 decryption threshold does **not**, by itself, establish that a particular DKG tolerates two malicious participants while preserving both secrecy and completion. That claim requires analysis of the selected protocol and its network and adversary assumptions. A failed setup ceremony may be aborted and repeated **before** the manifest is finalized rather than introducing complex in-election repair.

### 9.4 Key custody and catastrophic loss

There is **no backup copy of the complete private election key** and no emergency master key. Either would undermine the 3-of-5 separation of control. Trustees may have independently administered, audited backups of their **individual shares**, provided backup custody does not concentrate effective control of three shares in one person or organization. Backup arrangements themselves require threat analysis.

If three shares are irretrievably lost or unavailable, the election may become impossible to decrypt. Fides accepts that catastrophic availability risk rather than weaken the secrecy model. Deleting shares after finalization cannot undo a previous collusive disclosure. Key compromise and retention rules must be addressed in the operational security plan.

### 9.5 Bounded tally decoding

In exponential ElGamal, decrypting an aggregate reveals an encoded group element, from which the bounded integer count must be recovered. The selected parameters and decoding method must make this feasible for the maximum eligible tally, prevent modular ambiguity or wraparound, and support public verification of candidate totals. No performance or cryptographic security claim is made until the construction and bounds are specified.

## 10. Public bulletin board, transfer, completeness, and verification

### 10.1 The public record and canonical ballot identities

Every durably committed ballot receives a **unique accepted-ballot identity**, bound to the final manifest and authorized station. Its signed acceptance record binds that identity to the ciphertext and validity proof. The identity is assigned as part of the same atomic transaction as ballot commitment; it cannot be reused. The exact canonical encoding and identifier construction remain to be specified. Public identifiers should not reveal acceptance order or precise timestamps unless necessary for verification; internal accounting sequences need not be public.

A verifier rejects duplicate identities, conflicting signed records under one identity, malformed ballots, invalid validity proofs, records from unauthorized stations, and records bound to the wrong manifest. It recomputes the tally from **one canonical set of distinct accepted-ballot records** rather than accepting an arbitrary publisher-supplied ciphertext list. An identical ciphertext under a different identity is suspicious but is not, by itself, proof of duplicate voter participation; the entitlement state machine and independently audited authorization procedures address that separate issue.

### 10.2 Authenticated closing and complete offline export

Each station produces one ordinary signed final closing statement, binding the manifest, station, final accepted-ballot count, and a canonical cryptographic commitment to the **entire set of accepted-ballot identities, ciphertexts, and validity proofs**. The station's public export supplies all records necessary to reproduce that commitment, together with the authenticated opening and closing evidence and privacy-safe accounting data. Restricted voter-eligibility records are kept separately, not included in the public ballot export.

The transfer medium and courier are untrusted. The bulletin board and any independent verifier must check that an export matches the closing commitment **as an exact set**. A partial list of individually valid ballots is not a complete station export. An older snapshot is not a valid final closing statement. Two different signed final statements for the same station and election are conflicting evidence, not alternative legitimate versions to select opportunistically.

At least one independently controlled witness must preserve each station's authenticated closing commitment through an established custody procedure; multiple independent witnesses are preferable. A witness need not retain every ciphertext, but a digest cannot reconstruct missing records. Witnessing protects against subsequent rewriting only if an independent copy survives. Witness agreement on a dishonest closing record does not prove the station actually included every accepted ballot.

### 10.3 Incremental publication and final snapshot

The bulletin board may publish station exports **incrementally and provisionally**. It must clearly distinguish provisional publication from a finalized, complete election record. Each station in the signed manifest roster must have an explicit status, including missing, disputed, or invalidated; a station cannot silently disappear.

A final public snapshot has an unambiguous canonical representation and reproducible digest. Independent witnesses and verifiers compare this digest and the underlying signed station evidence, and expose conflicting published snapshots. A digest alone does not establish which of two conflicting final snapshots is legally authoritative. The finalization procedure must identify the authoritative snapshot, make contradictions visible, and preserve the records needed to verify it. The bulletin board is a publication service, not a trust anchor or an arbiter of conflicting signed histories.

### 10.4 Independent verification by every station

**Normative capability.** Every Fides station node shall be capable of independently verifying the final national election record, using only the authenticated final manifest commitment and publicly available election evidence. In particular, it shall:

1. Verify that the final publication snapshot is the independently authenticated authoritative snapshot and refers to the same final manifest used by the station.
2. Locate its own accepted-ballot records and check that **every ballot in its authenticated closing commitment** appears unchanged and exactly once in the final published set, with no conflicting identity or missing record.
3. Verify the authenticity, validity, exact-set commitments, and declared final status of all other stations in the manifest roster, subject to the same publicly disclosed disputes and completeness limitations as any independent verifier.
4. Recompute the election-wide encrypted aggregates from the canonical published ballot set and verify the trustees' partial-decryption proofs, combination, and reported national totals.

This verification shall not require privileged bulletin-board access, communication with other stations, trustee cooperation beyond the published proofs, or an online connection. A node may obtain the final evidence after voting and verify it offline. **Its conclusion is conditional on the authenticated accepted-ballot records and the independently established publication snapshot**; it cannot prove honest admission at other stations or discover an accepted ballot omitted from its own fraudulent closing history without external evidence.

**Optional corroboration.** A station may issue a signed verification statement bound to the final snapshot digest, stating whether verification succeeded and identifying any discrepancy. Such statements are additional independently checkable evidence, **not votes in a consensus protocol**. Unanimous station approval is not required for finalization, and a missing, destroyed, or malicious node cannot acquire a veto merely by withholding a verification statement. A node's assertion of success is not a substitute for independent verification of the underlying evidence.

The bulletin board may be one logical service and a single point of failure for *availability*, but shall not be the sole custodian of essential election evidence or a single point of trust for *integrity*. Authenticated exports must remain recoverable independently of the board, and a failed operator may be replaced under established governance without changing the election evidence.

### 10.5 What the public can establish

A sound public verifier can establish that all published ballots are valid, that each distinct authenticated accepted-ballot identity is counted exactly once, that each published station set matches its signed closing commitment, and that the reported totals follow from the canonical published set and verified aggregate decryption.

**It cannot, from those proofs alone, establish that every real voter was admitted honestly, every committed ballot was exported, or the station did not sign a fraudulent closing record.** Publication completeness relies on evidence external to the station's final self-report.

Three complementary sources are required:

1. **Signed individual acceptance statements**, optionally retained by voters, can expose specific omitted or substituted accepted ballots.
2. **Independent participation reconciliation**, based on actual completed voting events and separated from the node's self-reported ballot count, can expose numerical discrepancies and constrain fabricated admissions.
3. **Independently preserved closing commitments and publication comparisons** can expose later suppression, alteration, or conflicting station histories.

An independently certified participation count must be defined carefully: issued attempts, cancelled attempts, completed ballots, and unique voters are not interchangeable. A balanced ledger can still be fraudulent if officials collude. Likewise, a valid receipt proves that a station signed an acceptance statement, not that a legitimate voter was physically present.

### 10.6 Disputes, loss, and finality

A valid receipt for an accepted ballot absent from the finalized public set is evidence of conflicting station commitments and requires investigation. An authenticated closing commitment that disagrees with the published set also blocks uncontested technical verification. Conflicting final closing records cannot be resolved by automatically choosing the larger count or the first published record.

If the complete authenticated accepted-ballot set is irretrievably lost, receipts and closing hashes do not necessarily allow it to be reconstructed. Fides must not invent substitute ballots, solicit voter recollections as replacement votes, or silently certify a partial set. An unresolved loss may require invalidation under election law.

The applicable authority defines challenge deadlines, legal remedies and finality. A defined challenge period does not mathematically prove that no undiscovered omissions remain. No election may be called technically verified while known material evidence conflicts remain unresolved.

## 11. Signed acceptance statements, optional receipts, and privacy

**Decision:** Every durably committed ballot produces a station-signed acceptance statement capable of being supplied to the voter. Taking, keeping, or successfully printing a receipt is optional and never determines whether a committed ballot counts. A failed printer must not undo acceptance; reissuance is permitted where authenticated recovery procedures allow it.

The statement binds the final manifest hash, station identity, public accepted-ballot identity, and a commitment to the ciphertext and validity proof. It carries the station signature. A QR code is one possible presentation format, not a protocol primitive. The statement must contain **no voter identity, internal session identity, plaintext choice, encryption randomness, or unnecessary precise acceptance time**. Public ballot identifiers should avoid revealing voting order where feasible without weakening uniqueness and exact-set verification.

A voter can use the statement to check that the corresponding accepted ballot appears unchanged in the public record. Independent or local verification must be possible without sending the receipt identifier to a centralized tracking service. Convenience verification services may exist but can log receipt identifiers, network addresses and other correlating metadata; they are not a required trust dependency.

### 11.1 Secrecy is not receipt-freeness

A signed receipt and public ciphertext do not ordinarily reveal the candidate choice under secure encryption. They **do** associate the holder of the receipt with a specific ciphertext if disclosed. A coercer who obtains a receipt can verify its existence and potentially participation, and may correlate it with other observations. If cast-ballot encryption randomness is disclosed, the ciphertext may become a convincing proof of the selected choice. Three colluding trustees can decrypt the identified ciphertext directly, possibly without leaving public evidence. A compromised terminal or retained station identity-to-ciphertext records can likewise defeat practical secrecy.

Fides therefore claims **ballot confidentiality under its specified terminal, encryption and trustee assumptions**, not unconditional receipt-freeness, coercion resistance, or participation secrecy. Cast-ballot encryption randomness must never be given to the voter or included in the receipt. This restriction does not protect against a malicious terminal leaking it.

### 11.2 Retention and identity linkage

Station-local admission may temporarily link voter identity, session and encrypted ballot for atomic recovery, dispute handling and receipt reissuance. Public election records must not contain those identity links. The links are retained only while required for a defined operational or legal purpose, with restricted access, and discarded at the earliest safe point. There is no universal deletion deadline in the protocol. Deletion cannot undo copies already taken or associations inferred from observation, sequence or timing. Eligibility evidence and public ballot evidence are logically and operationally separated.

## 12. Cast-as-intended, failure, disputes, and legal finality

### 12.1 Cast-as-intended: an explicit residual trust assumption

A malicious terminal can show candidate A while encrypting candidate B. The ciphertext can pass validity proofs, appear unchanged on the bulletin board, and be correctly included in a publicly verified tally. **None of those proofs demonstrates that the terminal captured the voter's intent.**

**Decision for Fides v1:** independently tested terminals, controlled procedures, and human oversight are required, but the protocol does **not** add individual cryptographic cast-as-intended challenges. Consequently Fides does **not claim full end-to-end verifiability** in the strong technical sense. Its mathematical assurances target *recorded-as-cast* evidence (subject to independent acceptance evidence) and *tallied-as-recorded* correctness. Terminal assurance remains a significant residual risk, not a solved cryptographic property.

Challenge-ballot approaches were considered: a terminal commits to a prepared encryption before the voter chooses whether to cast it or reveal and independently verify its randomness and selection. Properly designed challenges can deter cheating, but require an independent verifier, a secure discard-and-retry procedure, and careful usability and coercion analysis. Randomly inserted test sessions are also imperfect: a malicious terminal may distinguish tests from real votes, and test ballots must not contaminate the tally. Neither mechanism is mandatory in v1. This is a deliberate scope decision, not a claim that tests make malicious terminals harmless.

### 12.2 Ordinary and exceptional failures

Ordinary terminal crashes, lost acknowledgements, receipt-printer failures, and concurrent cancellation requests are handled by the atomic session protocol in §7. Station-node durability failures must be detectable and cannot justify silently inventing or discarding accepted votes.

Exceptional events—irrecoverable station records, compromised critical keys, irreconcilable manifest or signed-history conflicts, or unresolvable tally and reconciliation failures—may require suspension, cancellation, or a fresh election under law. Fides prefers conspicuous failure to an unverifiable recovery.

The paper does not prescribe legal deadlines, adjudication standards, accessibility rules, recount rights, or the jurisdiction's remedy for a failed station. These are deployment obligations, not cryptographic conclusions.

## 13. Integrated adversarial review — findings and verdicts

The following findings test interactions among the admission protocol, station closing, offline export, public publication, receipts, manifest and trustee scheme. **Prevented** means under the stated assumptions and fully specified verification rules; **detectable** means independent evidence must survive; **procedurally mitigated** relies on human governance; **unresolved** means further design or proof is required.

| Attack or failure | Verdict | Basis or residual limitation |
|---|---|---|
| Terminal retries after uncertain commit | Prevented conditionally | Atomic durable state and idempotent recovery; no replacement of an already committed ballot |
| Delayed submission after cancellation | Prevented conditionally | One authoritative session transition; cancellation and commit mutually exclusive |
| Publisher repeats one accepted record | Preventable; formalization pending | Canonical accepted-ballot identity, uniqueness check, recomputed set-based aggregation |
| Station creates two distinct records for one voter | Procedurally mitigated | Entitlement state and independently audited eligibility; colluding officials can fabricate events |
| Courier changes ciphertexts or proofs | Prevented | Signed acceptance records and exact-set closing commitment |
| Courier deletes ballots | Detectable | Export cannot match independently preserved signed closing commitment |
| Courier supplies an older snapshot | Preventable | Only authenticated final closing statement qualifies; independent preservation matters |
| Station signs conflicting final histories | Conditionally detectable | Two surviving signed statements prove equivocation; neither is automatically authoritative |
| Bulletin board shows different ballot sets | Conditionally detectable | Public verification, final snapshot digests and independent comparison; disagreement must become visible |
| Publisher silently omits a station | Detectable | Manifest roster and mandatory explicit station status |
| Station and publisher suppress accepted ballots before witnessing | Conditionally detectable | Voter receipts and independent participation counts; may escape if independent evidence does not survive |
| Station fabricates ballots and matching eligibility records | Procedurally mitigated | Cryptography cannot establish real-world voter presence against colluding officials |
| Entire authenticated station export is destroyed | Potentially unrecoverable | Closing hash and receipts are not sufficient to reconstruct all encrypted ballots |
| Receipt holder tries to prove a vote choice | Confidential under assumptions, not receipt-free | Receipt alone does not decrypt; leaked encryption randomness or colluding trustees can reveal choice |
| Receipt-checking service tracks voters | Mitigable privacy risk | Independent/local checking, avoid mandatory centralized queries |
| Public ballot IDs expose voting order | Mitigable metadata risk | Avoid exposing internal sequences and precise timestamps unless necessary |
| Three trustees collude to decrypt individual ballots | Accepted limitation | 3-of-5 threshold protects against fewer than three, not against a threshold coalition |
| Trustees submit incorrect aggregate decryption | Prevented conditionally | Publicly verifiable partial decryptions and recomputed tally under sound construction |
| Fewer than three usable trustee shares survive | Fail-safe unavailability | No full-key backup; tally may be impossible |
| Conflicting signed final manifests | Procedural exception | Independently witnessed final commitment; conflicts require legal resolution, not silent choice |
| Terminal changes a displayed selection | Explicit trust assumption | No cryptographic cast-as-intended verification in v1 |

These are architectural verdicts, not formal security proofs. In particular, independent witnessing detects *conflicting evidence that survives*; it does not certify an otherwise fraudulent station history. Public tally correctness must never be conflated with honest admission or full publication completeness.

## 14. Architectural decisions and preferred candidates

| Topic | Status | Position |
|---|---|---|
| Physical voting | **Decision** | Supervised, private, in-person polling at assigned stations |
| Station connectivity | **Decision** | Operates without external connectivity during voting |
| Hardware and storage design | **Out of scope** | Protocol requirements, not prescribed devices, operating systems or databases |
| Admission | **Decision** | Identified station-local sessions; no blind signatures |
| Session semantics | **Requirement** | Separate voter entitlement and session; atomic durable commit/cancel; safe retries |
| Identity linkage | **Decision** | Temporary local association permitted; never public; purpose-limited retention |
| Cryptographic tally | **Preferred candidate** | Homomorphic threshold exponential ElGamal with ballot-validity and decryption proofs |
| Trustee governance | **Decision** | Five independent trustees; 3-of-5 threshold; explicit secrecy and liveness limits |
| Key generation | **Preferred candidate** | Reviewed compatible malicious-participant-aware DKG |
| Key backup | **Decision** | No master private key or full-key backup; separately controlled individual-share backups |
| Manifest | **Decision** | One signed, independently witnessed final hash; checked at station opening; immutable during voting |
| Public ballot identity | **Requirement** | Unique committed identity; signed binding to ciphertext/proof; avoid order leakage |
| Station closing | **Requirement** | One ordinary final closing statement binding exact accepted-ballot set and count |
| Offline export | **Requirement** | Complete authenticated export; untrusted transport; exact-set verification |
| Witnessing | **Requirement** | Independent custody of closing commitments and comparison with published evidence |
| Bulletin board | **Decision** | One logical publication service may fail for availability, but not serve as sole integrity trust or sole evidence custodian; provisional publication and canonical final snapshot |
| Independent station verification | **Requirement** | Every node can verify its own exact inclusion and the full national tally from public evidence; signed station verification statements optional, never a veto |
| Completeness | **Conditional assurance** | Receipts, independent participation reconciliation and witnessed commitments; not absolute proof |
| Acceptance statement | **Decision** | Created for every committed ballot; voter retention and QR presentation optional |
| Receipt privacy | **Requirement** | No identity, session, choice, randomness or unnecessary time/order data; independent checking |
| Cast-as-intended | **Trust assumption** | Independently tested terminals; no cryptographic challenge in v1 |
| Receipt-freeness / coercion resistance | **Not claimed** | Ballot confidentiality is conditional; stronger guarantees not provided |
| Full end-to-end verifiability | **Not claimed** | No cryptographic cast-as-intended verification |
| Mix-nets, blind signatures, blockchain | **Rejected/deferred for v1** | No established need justifies their complexity |
| Exceptional failure | **Decision** | Transparent suspension or invalidation rather than unverifiable reconstruction |

## 15. Remaining obligations and review order

**P1 — Continue integrated adversarial review.** Test complete cross-component traces, especially simultaneous station/publisher compromise, eligibility evidence and ballot-set reconciliation, conflicting witness views, receipt disputes, and finalization under partial availability. For every attack, identify adversary control, independent surviving evidence, violated property and conditional verdict.

**P2 — Exact cryptographic instantiation.** Select compatible, independently reviewed encryption, ballot-validity proofs, malicious-participant-aware DKG, threshold-decryption proofs, canonical encodings and domain separation. Specify ballot encoding, maximum tally size, bounded discrete-log decoding, and handling of malformed inputs. Verify actual security and liveness assumptions rather than extrapolating from the 3-of-5 threshold alone.

**P3 — Admission and record semantics.** Formalize voter entitlement, session states, accepted-ballot identity, transaction durability, cancellation, close-time unresolved sessions, receipt reissuance and crash traces. Prove that each committed ballot corresponds to one accepted record and that retries cannot create a second acceptance.

**P4 — Completeness and evidence custody.** Specify the exact station export and closing commitment, independent participation certification, witness acquisition timing, conflicting histories, provisional/final publication, public snapshot identity, dispute rules, and required retention of public evidence. Clearly separate *detected inconsistency* from *proof of the true ballot set*.

**P5 — Privacy and terminal assurance.** Establish testable safeguards for vote-intent capture, encryption randomness, receipt issuance and verification, metadata leakage, restricted identity-to-ciphertext association, retention and deletion. Fides v1 continues not to claim cast-as-intended cryptographic verification, receipt-freeness or coercion resistance.

**P6 — Governance and deployment.** Define manifest ceremony, trustee independence and individual-share backups, DKG abort handling, station key protection, incident response, legal finalization, accessibility, usability and real-world cost. No extraordinary recovery mechanism may quietly weaken the published trust model.

## 16. Next exercise and review checkpoint

The first integrated review has clarified **exact-once counting, authenticated offline export, station and bulletin-board equivocation, incremental publication, signed acceptance statements, and receipt-related privacy**. These refinements strengthen the original architecture without introducing a new cryptographic primitive. They do not establish unconditional publication completeness, honest voter admission or receipt-freeness.

After a short pause, resume with a systematic requirements-to-evidence audit: for every security objective in §4, identify its trust assumptions, normative protocol invariant, independently available evidence, verifier checks, and failure outcome. Search for circular reliance—for example, a station's own count being mistaken for independent proof of its completeness—and for requirements that remain descriptive rather than checkable. Only then proceed to exact cryptographic selection and formal protocol traces.

---

**Governing principle:** *Trust humans where human judgment is unavoidable. Demand publicly verifiable evidence wherever computation can replace trust.*
