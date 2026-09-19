#include "FIFO.h"

bool FIFO::empty() const {
    return head_ == NONE;
}

OrderID FIFO::front() const {
    return head_;
}
