## DISTRIBUTED VOTING SPECIFICATION - PART 1: THE NODE NETWORK

By shifting the voting infrastructure from a centralized state asset to a
peer-to-peer network operated directly by local municipalities, we eliminate
the single point of failure. Combining multi-party cryptography with explicit
human quorums creates an election model where a fraudulent state cannot
secretly manipulate the results.

### MUNICIPAL NODES & BYZANTINE PEER AUDITING

Instead of a singular central database, each municipality operates its own
independent validation node. These nodes process local ballots and maintain
a shared, distributed cryptographic ledger of the election.

```
+------------------+               +------------------+
|  Municipality A  |<------------->|  Municipality B  |
|   [Node Alpha]   |  Continuous   |    [Node Beta]   |
+--------^---------+  Peer Audits  +--------^---------+
         |                                  |
   10-Key|Fusion                      10-Key|Fusion
    +----+----+                        +----+----+
    |  Human  |                        |  Human  |
    | Council |                        | Council |
    |  (10)   |                        |  (10)   |
    +---------+                        +---------+
```

* Continuous Neighbor Auditing:
Nodes do not blindly accept data from other regions. The network uses peer-to-
peer cryptographic heartbeats. Every node continuously requests zero-knowledge
state-proofs from its neighbors, validating that no node's memory stack,
operating system binaries, or local ledger entries have been retroactively
altered.

* Neighbor-to-Neighbor Byzantine Auditing:
Nodes communicate via a Modified Byzantine Fault Tolerance (BFT) protocol
combined with Verifiable Delay Functions (VDF). Every 10 seconds, neighboring
nodes exchange a state root hash. If a state-level actor attempts to
manipulate the ledger entries on Node Alpha, the cryptographic hash tree
(Merkle Mountain Range) breaks sync with Node Beta.

Because the consensus threshold requires a 100% match for ledger consistency,
Node Beta instantly broadcasts a non-compliance alert, revoking Node Alpha's
validation rights and altering the peer network topology automatically. A
fraudulent state cannot quietly alter data on any single node without causing
the entire system to halt. Ideally, a fraudulent state must take over at
least 50% of all municipality nodes in order to rig an election (100% would be
best achieved by the strict, non-fault-tolerant consensus mechanism halting
on any single discrepancy).

## DISTRIBUTED VOTING SPECIFICATION - PART 2: THE COUNCIL OF 10

Cryptographic mathematics can prove structural consistency, but public
legitimacy requires human visibility. Every municipal node is physically and
digitally locked by a local Election Council composed of 10 trusted,
politically diverse, or randomly selected local citizens. Each municipality
node must be owned by these 10 trusted humans, who all must agree that no
tampering has occurred before they can propagate the voting result in their
municipality. Humans are intentionally inserted in different parts of the
voting process-not because it is strictly cryptographically necessary, but
because of trust to the voters. Humans trust humans.

### THRESHOLD CRYPTOGRAPHY (SHAMIR'S SECRET SHARING)

The master private key required to boot the municipal node, decrypt the
transmission channel, or sign the local results sheet does not exist as a
single file. It is hidden using a polynomial equation of degree k-1, where k
is the required human quorum (k = 10). A secret polynomial f(x) is constructed
locally inside a secure hardware security module (HSM) during the initial
keysigning ceremony:

`f(x) = a_0 + a_1*x + a_2*x^2 + ... + a_{k-1}*x^{k-1} (mod p)`

Where:

- `a_0 = S` (The secret private key).
- `a_1 ... a_{k-1}` are random large integers acting as coefficients.
- p is a large prime number (p > S).

Each of the 10 council members is allocated a unique point on this curve:
`(x_i, y_i)` where `y_i = f(x_i)`. The master key S remains completely non-existent
in memory until all 10 shards are combined using Lagrange polynomial
interpolation:

`S = SUM_{i=1..k} [ y_i * PROD_{j != i} (x_j / (x_j - x_i)) ] (mod p)`

```
   [Secret Master Key S]
             |
    +--------┴--------+  (Shamir Key Splitting)
    v                 v
[Share 1]  ...   [Share 10]  ---> Distributed to 10 Trusted Humans
```

* Unanimous 10-out-of-10 Consensus:
To activate the node or advance the election process, all 10 council members
must physically or digitally assemble and enter their respective key shards
into a local hardware token. If even one member refuses to cooperate due to a
suspected anomaly, the node remains locked, preventing unauthorized data
injection or premature reporting by a rogue administrator.

## DISTRIBUTED VOTING SPECIFICATION - PART 3: ANTI-FRAUD PIPELINE

To maximize trust among the electorate, humans are intentionally positioned
as gatekeepers and verifiers at every phase of the voting process.

```
  +---------------------------+
  | Step 1: ID Verification   | &lt;--- Handled by Human Election Workers
  +-------------┬-------------+
                |
                v
  +---------------------------+
  | Step 2: Digital Casting   | &lt;--- Voter verifies anonymous receipt hash
  +-------------┬-------------+
                |
                v
  +---------------------------+
  | Step 3: Local Mix-Net     | &lt;--- Council of 10 fuse keys to shuffle votes
  +-------------┬-------------+
                |
                v
  +---------------------------+
  | Step 4: Ledger Audit      | &lt;--- Public citizen groups run validation tools
  +---------------------------+
```

* Phase 1: Physical Check-In & Digital Token Issuance
Before any electronic ballot can be cast, the voter must present a physical
ID to human election workers at a municipal checkpoint. Once verified, the
human worker issues a localized, single-use hardware token or cryptographic
permission slip. This step ensures that a state-level bad actor cannot exploit
data leaks or generate artificial identities to flood the municipal nodes with
phantom votes.

* Phase 2: The Monitored Digital Drop Box
The voter fills out their ballot on a closed terminal, which encrypts the
data locally. As the voter submits the ballot, a screen displays an anonymous
tracking hash. The voter can see this hash drop onto the local screen, acting
as a digital receipt. Human observers monitor the physical terminals to ensure
no external devices are attached to the hardware.

The voter is provided with a digital receipt consisting of a cryptographic
hash tracking code. This tracking code does not reveal your political choice
(ensuring receipt-freeness, as a user should not be able to verify what he
voted for to an outside observer). Instead, it allows you to cross-reference
the public bulletin board to confirm your encrypted payload was successfully
received by the system.

* Phase 3: The Council-Sanctioned Local Shuffle & Mix-Net
When the voting window closes, the 10 council members inspect the physical
integrity of the node hardware. Once satisfied, they combine their key shards.
The node then executes a local Mix-Net shuffle, scrambling the order of the
votes and altering their outer encryption layers.

Votes are captured as ElGamal encrypted pairs `(c_1, c_2) = (g^r, m * h^r)`,
where m is the vote message, g is the generator, r is a random blinding factor,
and h is the public key. This allows the system to shuffle them dynamically by
altering r without modifying the underlying intent m.

```
[Raw Ballots Pile] ---> [Mixer 1: Shuffle + Re-encrypt] ---> [Mixer 2: Shuffle]
                             |                                    |
                             +---> (Outputs ZKP Proof)            +---> (ZKP)
```

To prove that the mixer did not discard any ballots or insert fraudulent
ones, the node generates a Proof of a Shuffle (using the Bayer-Groth
mechanism). This zero-knowledge proof verifies that the output set of
ciphertexts is a valid permutation and re-encryption of the input set:
`PROD_{i=1..N} (M_i) = PROD_{i=1..N} (M'_i)`

* Phase 4: Decentralized Public Auditing
After the shuffled votes from all municipalities are published to the global
ledger, the raw data, along with matching Zero-Knowledge Proofs (ZKPs), is
made entirely public. Independent citizen groups, university labs, and
opposition factions can download the data and run their own verification
scripts. Voters do not need to understand the underlying mathematics; they
gain trust by seeing that dozens of independent, user-created auditing tools
all produce a matching green confirmation indicating that the mathematical
ledger is pristine.

### DECONSTRUCTING AND FIXING THE "ESTONIAN VULNERABILITIES"

While Estonia's internet voting model is pioneering, it contains architectural
vectors that security experts criticize. Our municipality-distributed
architecture introduces structural fixes to these exact vulnerabilities.

VECTOR: Centralized Point of Trust
Estonia: The final tally and verification rely entirely on a central National
Election Committee server.
FIX: Decentralized Municipal Sharding-Tallies are split across distinct nodes.
No single server holds the master decryption key or complete ledger control.

VECTOR: The In-Home Coercion Window
Estonia: An attacker can theoretically confiscate a voter's digital ID
credentials (e.g., SIM card) for the entire duration of the voting week.
FIX: Physical Human Gatekeeping-Electronic tokens can only be activated after
a face-to-face biometric or physical ID verification at a local municipality
site, making automated or distant bulk identity theft impossible.

VECTOR: Device Compromise (Malware)
Estonia: Rogue malware on a consumer PC could manipulate the browser display,
showing the user they voted for Option A while sending Option B to the server.
FIX: Hardware Separation & Sealed Terminals-Voting occurs on offline-capable
local municipality terminals with strict hardware enforcement, eliminating
the insecurity of consumer laptops.

Advanced Coercion Resistance Architecture:
To counter sophisticated coercion scenarios, our network integrates a physical
override protocol:

1. If an adversary threatens a voter or buys their vote, the voter can comply
   during the digital token acquisition step.
2. However, the system enforces a legal protocol where an In-Person Physical
   Paper Ballot always takes absolute precedence over any digital ledger entry.
3. If a citizen casts a digital ballot under duress, they can walk into their
   local municipality polling station and drop a physical paper ballot into
   a secure box.
4. When the Council of 10 verifies the physical box, the local node
   automatically flags the voter's digital cryptographic tracking hash as
   "Superseded by Paper" and drops it from the digital Mix-Net pool before
   the final global calculation.

Because the physical paper trail cannot be tracked or audited by the coercer
after the voter enters the curtained booth, the absolute secrecy of the
ballot is restored, rendering digital coercion economically and operationally
useless.
