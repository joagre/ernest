# DISTRIBUTED VOTING SPECIFICATION

*Proposed architecture — cryptographic protocols, trust assumptions, operational procedures and security guarantees require formal specification, independent review and testing before deployment.*

## PART 1: THE NODE NETWORK

By distributing election infrastructure across independently operated municipal nodes, the system aims to reduce dependence on any single central authority. Combining multi-party cryptography, public verification and explicit human quorums creates an election model in which unauthorized manipulation should be detectable without relying solely on the honesty of the state.

Decentralization does not, by itself, eliminate every single point of failure. Common software defects, compromised election parameters, coordinated attacks and network disruption remain possible. The design must identify and address these shared dependencies.

### MUNICIPAL NODES & BYZANTINE PEER AUDITING

Instead of a single central database, each municipality operates an independent validation node. These nodes process local ballots and participate in maintaining a shared, cryptographically authenticated election record.

```text
+------------------+               +------------------+
|  Municipality A  |<------------->|  Municipality B  |
|   [Node Alpha]   |   Authenticated|   [Node Beta]   |
+--------^---------+   Peer Exchange+--------^---------+
         |                                  |
   Council|Approval                   Council|Approval
    +----+----+                        +----+----+
    |  Human  |                        |  Human  |
    | Council |                        | Council |
    |  (10)   |                        |  (10)   |
    +---------+                        +---------+
```

**Continuous Neighbor Auditing**

Nodes do not blindly accept data from other municipalities. They exchange authenticated commitments to election records and verify the associated signatures, consistency proofs and protocol certificates.

A cryptographic hash can demonstrate that two parties possess identical data or detect a change relative to a previously authenticated commitment. It cannot establish that a remote machine's memory, operating system or hardware is uncompromised. Such claims require separate attestation mechanisms and trust assumptions.

**Neighbor-to-Neighbor Byzantine Auditing**

Municipal nodes participate in a specified Byzantine fault-tolerant replication or publication protocol. Nodes exchange authenticated state commitments and verify that published election records extend the agreed history consistently.

A Merkle tree or Merkle Mountain Range may provide efficient inclusion and consistency proofs. Conflicting authenticated histories must produce publicly verifiable evidence of equivocation.

The consensus protocol must explicitly define its membership, fault threshold, finality rules, network assumptions and recovery procedures. Periodic hash exchanges, potentially every 10 seconds, may assist monitoring but do not themselves establish consensus.

A detected inconsistency must trigger an alert and prevent the affected evidence from being accepted until the discrepancy is resolved. Automatic revocation of a node's authority requires a separately specified, authenticated decision procedure; disagreement alone is not sufficient evidence of malicious behavior.

A strict unanimity requirement can prevent conflicting results from being finalized, but it also allows one unavailable or uncooperative participant to halt progress. The system must therefore distinguish safety from availability.

No fixed percentage of compromised municipalities can be claimed sufficient or necessary to manipulate an election until the consensus and certification protocols have been selected and analyzed.

**Independent Municipal Result Verification**

Each municipality retains an authenticated copy of its certified election record and the corresponding cryptographic commitment.

After nationwide aggregation, the municipality independently verifies that its exact certified contribution appears in the final published record. The network must also provide sufficient public evidence to verify the completeness of the municipal result set and the correctness of the national aggregation.

The complete verification procedure is specified in Part 4.

## PART 2: THE COUNCIL OF 10

Cryptographic mathematics can establish properties of election data and computations, but public legitimacy also depends on transparent human oversight.

Every municipality establishes an Election Council composed of 10 citizens selected through a publicly defined process intended to promote independence, political diversity and public confidence.

The council supervises critical election operations, verifies the evidence presented for approval and certifies the municipality's final election record.

The council's approval must be tied to precisely identified cryptographic data. Its members must be able to inspect the relevant evidence, rather than merely authorize an opaque operation.

Human oversight is deliberately included because voters should not have to place their trust exclusively in software or central institutions. Human approval supplements cryptographic verification; it does not replace it.

### THRESHOLD CRYPTOGRAPHY (SHAMIR'S SECRET SHARING)

Shamir's Secret Sharing can distribute control of a secret among multiple council members.

For a quorum of k members, a secret S can be represented as the constant term of a polynomial of degree k−1 over a finite field:

`f(x) = a_0 + a_1*x + a_2*x^2 + ... + a_{k-1}*x^{k-1} (mod p)`

Where:

- `a_0 = S`, the protected secret.
- `a_1 ... a_{k-1}` are independently generated random field elements.
- `p` is the prime defining the field, with the secret represented as an element of that field.

Each council member receives a unique share `(x_i, y_i)`, where `y_i = f(x_i)`.

Any k valid shares reconstruct the secret through Lagrange interpolation:

`S = SUM_{i=1..k} [ y_i * PROD_{j != i} (x_j / (x_j - x_i)) ] (mod p)`

All arithmetic is performed in the finite field.

```text
       [Protected Secret S]
                |
       Shamir Share Creation
                |
       +--------+--------+
       |        |        |
   [Share 1]   ...   [Share 10]
       |                 |
   Council Member 1   Council Member 10
```

For a 10-out-of-10 scheme, all ten shares are required to reconstruct the secret.

However, reconstructing a master private key on a municipal node creates a sensitive moment during which that key may be exposed. Wherever practical, the system should instead use independently reviewed threshold-signature and threshold-decryption protocols that perform the required operation without reconstructing the complete private key.

Separate cryptographic keys and authorization procedures must be used for node administration, communication authentication, council certification and ballot decryption. A single master key must not control all these functions.

**Unanimous 10-out-of-10 Council Approval**

Critical municipal certification decisions require the explicit approval of all 10 council members.

Each approval must identify the exact election, municipality, record digest and operation being authorized. Approval must be authenticated and recorded in a publicly verifiable form.

If any member refuses to approve, certification remains pending. This provides a deliberate human veto but introduces an availability risk: absence, loss of credentials or obstruction by one member can prevent completion.

The system must define recovery, replacement, dispute and incident procedures in advance. These procedures must not permit an administrator to bypass the required authorization threshold.

Unanimous council approval establishes collective authorization. It does not, by itself, prove that the underlying election data is correct.

## PART 3: ANTI-FRAUD PIPELINE

Human election workers, municipal councils and independent auditors participate at different stages of the voting process.

```text
+---------------------------+
| Step 1: ID Verification   | <-- Human Election Workers
+-------------+-------------+
              |
              v
+---------------------------+
| Step 2: Digital Casting   | <-- Private Voter Verification
+-------------+-------------+
              |
              v
+---------------------------+
| Step 3: Local Mix-Net     | <-- Verifiable Cryptographic Shuffle
+-------------+-------------+
              |
              v
+---------------------------+
| Step 4: Ledger Audit      | <-- Independent Public Verification
+-------------+-------------+
              |
              v
+---------------------------+
| Step 5: Local Certification| <-- Council of 10
+-------------+-------------+
              |
              v
      National Verification
             (Part 4)
```

**Phase 1: Physical Check-In & Digital Token Issuance**

Before casting an electronic ballot, a voter presents acceptable identification to authorized election workers at a municipal polling location.

After verifying eligibility and checking that the voter has not already received an incompatible voting entitlement, the election workers authorize a single-use voting credential.

The authorization process must prevent unauthorized creation, duplication and reuse of voting entitlements. It must also preserve ballot secrecy by preventing the identity record from being linked to the voter's eventual choice.

Human identity checks reduce some forms of remote impersonation and automated fraud. They do not establish that the underlying voter register is accurate or that election workers cannot collude.

Independent reconciliation of eligibility records, issued credentials, accepted ballots and exceptional cases is therefore required.

**Phase 2: The Monitored Digital Drop Box**

The voter completes a ballot on a controlled municipal voting terminal. The ballot is encrypted before submission.

The terminal provides a cryptographic receipt allowing the voter to check that the corresponding encrypted ballot appears in the public election record.

The receipt must not reveal the selected candidate or provide transferable evidence of the voter's choice.

Human observers supervise the polling environment and physical equipment without being able to observe individual votes.

A receipt or tracking hash can support recorded-as-cast verification, but it does not by itself prove that the terminal encrypted the choice the voter intended. The protocol must separately specify how voters or independent auditors can detect incorrect ballot preparation.

The system must also distinguish between a submitted ballot, an accepted ballot and a ballot included in the final tally.

**Phase 3: The Council-Sanctioned Local Shuffle & Mix-Net**

When the voting window closes, the municipality establishes its final accepted encrypted ballot set under the agreed closure procedure.

The Council of 10 examines the required closure evidence and authorizes the transition to tally processing.

The municipality then performs a verifiable cryptographic shuffle to break the association between ballot submission order and the ballots used for counting.

One possible construction uses ElGamal encryption:

`(c_1, c_2) = (g^r, m * h^r)`

Where:

- `m` represents the encoded vote.
- `g` is a generator of the selected cryptographic group.
- `r` is a randomly selected encryption exponent.
- `h` is the election public key.

A correctly implemented ElGamal re-encryption changes the ciphertext randomness without changing the underlying plaintext.

```text
[Accepted Encrypted Ballots]
              |
              v
[Mixer 1: Shuffle + Re-encrypt]
              |
         Shuffle Proof
              |
              v
[Mixer 2: Shuffle + Re-encrypt]
              |
         Shuffle Proof
              |
              v
[Final Shuffled Ballot Set]
```

Each mixer publishes a zero-knowledge proof demonstrating that its output is a valid permutation and re-encryption of its input.

A suitable, fully specified shuffle-proof system, such as a Bayer–Groth construction, may be used.

The proof must establish the required permutation and re-encryption relation over the complete ciphertext sets. Equality of products alone is not sufficient to prove a correct shuffle.

The system must additionally verify that the original accepted ballot set is complete, that each ballot is valid, and that every eligible accepted ballot is counted exactly once.

The protocol must define how shuffled ballots are decrypted or otherwise tallied, together with publicly verifiable proofs of the correctness of that operation.

**Phase 4: Decentralized Public Auditing**

The election system publishes the cryptographic evidence needed to verify ballot acceptance, shuffle correctness and tally computation.

Independent citizen groups, universities, political parties and other auditors must be able to obtain the complete public election record and execute independent verification software.

Publicly available evidence may include encrypted ballots, authenticated commitments, shuffle proofs, decryption or tally proofs, certification signatures and final results.

Private voter identities, secret credentials and other information capable of compromising ballot secrecy must not be published.

Verification must fail when required evidence is missing, inconsistent or invalid. A successful cryptographic check establishes only the properties actually covered by the verified proofs and their stated assumptions.

**Phase 5: Municipal Result Certification**

After local processing and verification, the Council of 10 certifies the municipality's final election record.

The certification binds the municipality's identity, election identifier, final accepted ballot-set commitment, relevant cryptographic proofs and certified contribution to the national tally.

All 10 council members must approve the exact same canonical record.

The municipality retains the certified record and publishes it through the distributed election network.

National aggregation and the independent verification of municipal contributions are specified in Part 4.

## PART 4: MUNICIPAL CERTIFICATION AND NATIONAL TALLY VERIFICATION

The final nationwide election result must be independently verifiable by every municipality and by any member of the public.

No municipality's certified contribution may be silently altered, omitted, duplicated or replaced during national aggregation.

The verification mechanism must not require trusting a central tallying authority.

### 4.1 MUNICIPAL RESULT CERTIFICATION

Every municipality produces a canonical, cryptographically authenticated election record containing:

1. The election identifier and municipality identifier.
2. The final accepted encrypted ballot-set commitment.
3. The number of accepted ballots and the applicable reconciliation evidence.
4. The municipality's certified tally contribution, represented either as public totals or as cryptographically committed values.
5. The cryptographic proofs necessary to verify that the contribution was correctly derived from the accepted ballots.
6. The authenticated approvals of all 10 council members.

The exact encoding and cryptographic profile must be specified before deployment.

Council signatures authenticate approval of the record. The accompanying proofs establish its mathematically verifiable properties.

Neither signatures nor cryptographic proofs establish the real-world accuracy of the voter register or the honesty of physical identity checks.

### 4.2 CRYPTOGRAPHIC PROOF OF THE MUNICIPAL TALLY

The municipality must provide sufficient evidence for an independent verifier to establish that its certified contribution corresponds exactly to its final accepted ballot set.

Verification must establish that:

- Every counted ballot belongs to the authenticated accepted set.
- Every accepted ballot is represented exactly once, subject to explicitly defined and verifiable exclusion rules.
- Every counted ballot satisfies the required ballot-validity conditions.
- Every shuffle is a valid permutation and re-encryption.
- Every decryption or tally operation is cryptographically justified.
- The certified contribution corresponds to the verified computation.

A mix-net proof alone is insufficient: it proves a relationship between encrypted input and output sets, not the correctness of the original ballot set or the final tally.

The selected cryptographic protocol must define the complete verification chain.

### 4.3 NATIONAL RESULT COMMITMENT

The national election record contains the complete set of certified municipal contributions.

Records must use a canonical encoding and deterministic ordering, with unique municipality identifiers and an authenticated election identifier.

A Merkle tree may commit to the complete ordered set:

```text
 Certified A     Certified B     Certified C     Certified D
     |               |               |               |
     v               v               v               v
   Hash A          Hash B          Hash C          Hash D
     |               |               |               |
     +-------+-------+               +-------+-------+
             |                               |
          Hash AB                         Hash CD
             |                               |
             +---------------+---------------+
                             |
                         Merkle Root
                             |
                             v
                  National Election Record
```

The Merkle root binds the published national record to the exact municipal records included in the tree.

Each municipality must be able to obtain an inclusion proof for its certified record.

The complete canonical municipal record set must also be publicly available, or an equivalently complete and independently verifiable representation must be provided.

A Merkle root alone does not prove that the national record contains every municipality or that the national tally is correct.

### 4.4 INDEPENDENT MUNICIPAL VERIFICATION

After publication of the national record, each municipality independently verifies:

1. That the published election identifier is correct.
2. That its exact certified record appears in the committed national dataset.
3. That its record has not been modified or replaced.
4. That the record's council approvals are valid.
5. That the published national record is consistent with the authenticated final election publication.

The municipality must not be required to trust the national tallying authority's assertion that these checks succeeded.

The verification evidence must be reproducible by independent auditors.

### 4.5 INDEPENDENT NATIONAL VERIFICATION

Any independent verifier must be able to establish that:

1. The national record contains exactly the expected municipalities, according to an authenticated and frozen municipality register.
2. No municipality is omitted or duplicated.
3. Every municipal certification is authentic and valid.
4. Every municipal tally contribution is supported by the required cryptographic evidence.
5. Every included contribution is bound to the published national commitment.
6. The aggregation of all certified contributions produces the announced nationwide result.

If municipal plaintext totals are published, the national result can be independently recomputed by summation:

`NationalTotal(candidate) = SUM MunicipalTotal(municipality, candidate)`

If municipal contributions remain encrypted or committed for privacy reasons, the protocol must provide an equivalent publicly verifiable aggregation proof.

The design must explicitly address the risk that publishing results for very small voting populations could compromise ballot secrecy. Grouping small populations or using cryptographic aggregation without publishing individual municipal plaintext totals may be necessary.

### 4.6 DISCREPANCIES AND CERTIFICATION FAILURE

Any municipality or independent auditor must be able to report a discrepancy supported by publicly verifiable evidence.

Examples include:

- A missing municipality.
- A duplicated municipal record.
- A municipal record differing from its authenticated certification.
- Invalid or missing council approvals.
- Invalid ballot, shuffle, decryption or tally proofs.
- An incorrect national aggregation.
- Conflicting authenticated national election records.

A missing required record or proof makes verification incomplete. Contradictory or invalid evidence makes the affected verification fail.

The nationwide result must not be certified as verified while an unresolved discrepancy prevents the required checks from succeeding.

Resolution procedures must be defined before the election. They must preserve the original evidence and must not permit unilateral replacement of a certified municipal result.

**The fundamental requirement is that a national election result must be verifiable from authenticated municipal contributions and public cryptographic evidence, not from trust in the authority announcing the result.**

## PART 5: COMPARISON WITH ESTONIA'S INTERNET VOTING SYSTEM

Estonia's internet voting system provides an important reference for the design of verifiable electronic elections. The proposed municipality-distributed architecture makes different choices about institutional control, voting location and human oversight.

These choices are intended to address particular threat scenarios. They do not establish that the proposed system is categorically more secure than Estonia's existing system.

### VECTOR: CENTRALIZED POINT OF TRUST

**Estonia:** Election administration, cryptographic key management and tallying depend on designated institutions and procedures. The system also employs cryptographic verification and operational controls; it should not be characterized as relying entirely on a single server.

**PROPOSED DESIGN:** Municipalities operate independent nodes and certify their own contributions. The final result is derived from authenticated municipal records and publicly verifiable aggregation evidence.

The objective is to reduce the power of any single administrative authority to alter the result undetected.

### VECTOR: THE IN-HOME COERCION WINDOW

**Estonia:** Remote internet voting introduces coercion and credential-misuse risks associated with voting outside a supervised environment. Estonia's system includes mechanisms intended to mitigate these risks, including revoting arrangements.

**PROPOSED DESIGN:** Voting takes place at supervised municipal locations after in-person eligibility checks.

This reduces exposure to some remote coercion and credential-theft scenarios, although it does not eliminate coercion, impersonation or dishonest election workers.

### VECTOR: DEVICE COMPROMISE (MALWARE)

**Estonia:** A compromised voter device can attempt to misrepresent the voter's choice or interfere with ballot submission. Verification mechanisms are intended to detect certain attacks.

**PROPOSED DESIGN:** Voting occurs on controlled municipal terminals subject to physical supervision, software integrity procedures and independent auditing.

Dedicated terminals reduce reliance on voters' personal computers, but they remain vulnerable to malicious software, compromised supply chains and insider attacks.

The system therefore requires independently verifiable ballot preparation, acceptance and tally procedures.

### ADVANCED COERCION RESISTANCE: PAPER BALLOT OVERRIDE

The proposed design considers a physical paper-ballot override mechanism:

1. A voter who has cast a digital ballot may subsequently cast a paper ballot at an authorized municipal polling station.
2. Under the predetermined election rules, the valid paper ballot takes precedence over the earlier digital ballot.
3. The system must prevent both ballots from being counted while preserving the secrecy of the voter's choice.
4. Any exclusion of a superseded digital ballot must be authenticated, auditable and correctly reflected in the final accepted ballot set.
5. The procedure must prevent the published election record from revealing the voter's political choice or providing a transferable proof of how the voter voted.

A paper override may mitigate some coercion scenarios, but it does not guarantee coercion resistance. An adversary may monitor the voter, prevent subsequent voting or coerce the voter at the polling location.

Furthermore, identifying and excluding an earlier digital ballot creates a potential link between voter identity and ballot activity. The protocol must define how this operation can be performed without exposing vote choices or undermining anonymity.

This override mechanism remains a proposed extension requiring a complete cryptographic and operational design before it can be accepted as a security guarantee.

---

## DESIGN STATUS

This specification defines the intended institutional structure and verification requirements. It does not yet constitute a complete or proven election protocol.

The principal unresolved design decisions include the Byzantine consensus protocol and fault assumptions; the council's threshold-signing and authorization mechanisms; the exact ballot-validity, shuffle, decryption and tally proofs; the privacy-preserving representation of municipal contributions; the binding between voter eligibility and anonymous ballots; the paper-override mechanism; and the procedures for recovering from missing participants or conflicting certifications.

These decisions must be resolved through a concrete protocol specification, adversarial analysis, independent review and testing before any claim of election-grade security is justified.
