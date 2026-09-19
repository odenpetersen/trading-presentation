citations for everything so its not "leaking alpha"

talk is free of AI slop

quotes:
https://www.alice-in-wonderland.net/resources/chapters-script/alices-adventures-in-wonderland/chapter-1/
OSTEP epigraphs

Note existence of previous talk

note at some point usefulness of microstructure for MFT stuff


("Speed is the essence of war." Sun Tzu)
"Eternity is in love with the productions of time." William Blake
"Truth was the only daughter of Time." Leonardo da Vinci
"Time drives everything before it, and is able to bring with it good as well as evil, and evil as well as good." Niccolò Machiavelli,
"Time is the most valuable thing a man can spend." Theophrastus
"Time is the inexorable process of doing computation." Stephen Wolfram
"Time is a necessary representation, lying at the foundation of all our intuitions ... In it alone is all reality of phænomena possible. These may all be annihilated in thought, but time itself, as the universal condition of their possibility, cannot be so annulled." Kant
"Capital, in its ultimate self-definition, is nothing beside the abstract accelerative social factor. Its positive cybernetic schema exhausts it.  Runaway consumes its identity." Nick Land
"All economic activity is carried out through time." Hayek
"Entropy and extropy have opposing time-signatures, so that time-reversal is a relatively banal cosmological fact. ‘We’ inhabit a bubble of backwards time (whoever we are), whilst immersed in a cosmic environment which runs overwhelmingly in the opposite direction. If reality is harsh and strange, that’s why." Nick Land
"We affirm that the world's magnificence has been enriched by a new beauty: the beauty of speed." Filippo Marinetti
"Nature to be commanded must be obeyed; and that which in contemplation is as the cause is in operation as the rule." Francis Bacon
"I often say that when you can measure what you are speaking about, and express it in numbers, you know something about it; but when you cannot measure it, when you cannot express it in numbers, your knowledge is of a meagre and unsatisfactory kind; it may be the beginning of knowledge, but you have scarcely, in your thoughts, advanced to the stage of science, whatever the matter may be." William Thomson, Lord Kelvin
"As eternity is reckoned there's a lifetime in a second." Piet Hein
"There is no science apart from the general. It may even be said that the very object of the exact sciences is to spare us these direct verifications." Poincare
"Science is when it works but shouldn’t. Engineering is when it doesn’t work but should." Sam Altman
"All great events hang by a hair." Napoleon

# Trading as an engineering problem. Why do you care?
You get to build things that do things.

# Latency in the trading problem

Microstructure represents idio alpha.

Adverse selection (probably recurring theme)

compliance is recurring theme but also a grey area. 

Fill rate


"To every thing there is a season, and a time to every purpose under the heaven ... A time to get, and a time to lose; a time to keep, and a time to cast away." Ecclesiastes

## Timestamping
Clocks
Clock drift ("Oh my fur and whiskers! I'm late, I'm late, I'm late!" alice in wonderland)
PTP, NTP, Hardware, CPU TSC
white rabbit?
Relativity: https://en.wikipedia.org/wiki/One-way_speed_of_light#Einstein_convention
Round trip time

# Egress
us to exchange. We have somehow decided we want to buy, quote, cancel, etc.

DMA, colocation. Show picture of HKEX data centre

Risk checks

network protocols. TCP, sequence numbers. OSI model.

PCAPs, wireshark

Packetisation. MTU and jumbo frames. ("being so many different sizes in a day is very confusing" alice in wonderland)
Packet header reading

Serialisation latency. ("Time exists in order that everything doesn’t happen all at once" Ray Cummings)
Copper is faster than fibre https://news.ycombinator.com/item?id=44435309 :). Cross-connects: fiber,eth,coax; gbps; https://www.reddit.com/r/chipdesign/comments/1arh2vr/what_is_a_phy/

cut-through vs SAF

Multi-shooting, sessions, gateways, idempotency
Probabilistic queueing models

# Matching Engine
## Algorithms
CLOB. Priority. How to efficiently maintain.
Must be serialised. Perhaps even across products due to eg capitalisation requirements & position limits
Self-match prevention (might come up elsewhere in talk). Cancellation

Metadata e.g. order IDs. Look for patterns. (Need to find public citation)

Optimised for throughput first, latency later. Exchanges want to penalise things that lead to high throughput.

## Cache warming

# Ingress
exchange to us

Market data: incremental, snapshot, etc. private feed (acks, traded, canaries)
Multicast, UDP, TCP

NIC, rx queue (and other tcp), drop-copy
SmartNIC, FPGA in NIC, PCIe
https://www.reddit.com/r/networking/comments/1l5tuho/difference_between_nic_dma_ring_buffer_and_rx/

store-and-forward congestion, backpressure, etc. ("The hurrier I go, the behinder I get." alice in wonderland)

## Feed Arbitration

## Delay modeling
Jitter, tail latency, queueing
Fixed, random, conditional, autocorrelated. Predictive of future stuff (can leave vague-ish). ("The race is not to the swift, nor the battle to the strong, nor bread to the wise, nor riches to the intelligent, nor favor to the men of skill; but time and chance happen to them all." Ecclesiastes; "The race is not always to the swift, nor the battle to the strong – but that’s the way to bet." Anon)

## WAN
market data, alt data
ping time
https://share.google/aimode/50XpWt7Rufat36tsG

# W2W
"You cannot conquer Time." W. H. Auden

Decision to make a trade. Modeling, adverse selection, etc.

Trigger-based. ("Ease and speed in doing a thing do not give the work lasting solidity or exactness of beauty." Plutarch, Life of Pericles.)
Book event simulation. FPGA design; clocks, clock edges, overclocking. talk about different NIC models w pros/cons

## Kernel Bypass
interrupts vs polling
direct memory access

## Packet splitting
Pre-sending, out-of-order sending, subsequent invalidation, etc.

## Negative latency

# Trigger refresh

## Software Autotrading
"Time is not composed of indivisible nows any more than any other magnitude is composed of indivisibles." Aristotle. Physics VI. Part 9 verse: 239b5
Time complexity picture. EMAs, exp weighted microprice (pose as a puzzle, whats best microprice update time complexity you can get with certain properties), etc.

Making fast machine code

interrupt storms
OS-level stuff, three easy pieces, async programming
CPUs and von neumann architecture
Overclocking https://www.blackcoretech.com/
fetch decode execute
Cache invalidation, latency of different cache levels. LFU/LRU algorithm
Tomasulo algo
Branch prediction incl perceptrons. "Time forks perpetually toward innumerable futures." Borges
Why linked lists suck
x-free programming https://chatgpt.com/share/6a9817de-0990-83ec-b578-2bbf2ef877cb
garbage collection
SIMD
multi-core systems

https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/performance_tuning_guide/main-network#s-network-future

### C++ compilation
godbolt demo

source
AST
compiler IR
assembly
instructions
-O0 vs -O3
inlining
branch elimination
virtual calls
bounds checks
vectorisation

optimising some actual code live. Start with how an exchange would implement a CLOB, and go to how a HFT would implement it.

## GPU inference
CUDA, warps
talk about pros/cons of different GPU models, how to evaluate
Why trees are slow. Universal approximation theorem does not apply for shallow forests.
Fitting in memory. Quantisation, multiple GPUs, etc.; cross-sectional common components; state-based models for O(n) sequence processing. Caching model components with no new info.
