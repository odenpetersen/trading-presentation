ded Matching Engine

Implement a small self-contained C++ matching-engine simulation.

## Invocation

The executable accepts one optional command-line argument:

```text
./engine [N]
```

`N` is the number of validation worker threads. Default to `1`. `N >= 1`.

## Message format

Define an `OMNET` message containing:

* `sender`: `uint32_t`
* `port`: `uint16_t`
* `type`: `GFD`, `FAK`, or `CANCEL`
* `price`: `double`
* `qty`: `uint32_t`

Messages are supplied to the engine as if decoded from a TCP byte stream. Actual exchange-grade TCP framing is not required; a simple deterministic input mechanism is sufficient.

## Sender/port validation

Maintain a mapping:

```text
sender → port
```

The first message received from a sender establishes its port.

Subsequent messages from that sender are valid only if they use the same port. Messages violating this rule are rejected and must never reach the processing queue.

Validation is performed by the `N` worker threads.

## Queues and threading

Use two stages:

```text
input queue
     │
     ├── validation worker 1
     ├── validation worker 2
     ├── ...
     └── validation worker N
             │
             ▼
      processing queue
             │
             ▼
     single matching thread
```

The input/network thread places decoded messages into the input queue.

Each validation worker:

1. Takes one message from the input queue.
2. Validates its sender/port relationship.
3. If valid, appends it to the processing queue.
4. Otherwise discards it.

The processing queue must be thread-safe.

**No ordering relationship is required between messages during validation.** The order in which validated messages enter the processing queue defines their processing order.

Exactly one thread owns and modifies the order-book state.

## Order IDs

The matching thread assigns a monotonically increasing `uint64_t` order ID to every valid message that reaches it.

Rejected messages consume no order ID.

## Order book

Maintain a basic price/time-priority limit order book.

A `GFD` order:

1. Matches immediately against eligible resting orders on the opposite side.
2. Any unfilled quantity is inserted into the book.

A `FAK` order:

1. Matches immediately against eligible resting orders.
2. Any unfilled quantity is discarded.
3. No remainder is added to the book.

`CANCEL` removes the referenced resting order. The exact cancellation-reference field may be added to `OMNET` as necessary.

Trades should contain at least:

* aggressor order ID
* resting order ID
* price
* quantity

## Market data

After every accepted order-book state transition, publish an incremental market-data message over UDP multicast.

Each market-data message contains a monotonically increasing `uint64_t` sequence number.

The sequence number is owned exclusively by the matching thread and increments in processing order.

The market-data message should describe the resulting change, e.g. order addition, cancellation, or trade.

Use a fixed multicast address/port; no configuration system is required.

## Concurrency requirements

The implementation must guarantee:

* No data races.
* No concurrent modification of the order book.
* No concurrent modification of order IDs or market-data sequence numbers.
* A message rejected by validation never reaches the processing queue.
* Every message is processed exactly once after entering the processing queue.
* Processing order is exactly the order in which valid messages are inserted into the processing queue.

When `N=1`, the same architecture must still be used: one validation worker and one matching thread.

## Scope

Do not implement exchange-grade networking, persistence, recovery, authentication, sophisticated risk checks, or lock-free data structures unless required by the implementation.

The objective is a small, faithful demonstration of:

**concurrent ingress validation → serialised order-book processing → incremental multicast market data.**
