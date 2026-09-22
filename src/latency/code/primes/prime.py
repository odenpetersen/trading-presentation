#!/usr/bin/env python3
def is_prime(n: int) -> bool:
    # Numbers less than or equal to 1 are not prime
    if n <= 1:
        return False
    # 2 is the only even prime number
    if n == 2:
        return True
    # Exclude all other even numbers
    if n % 2 == 0:
        return False
    
    # Check odd factors up to the square root of n
    for i in range(3, int(n**0.5) + 1, 2):
        if n % i == 0:
            return False
            
    return True

# Examples:
print(is_prime(11))  # Output: True
print(is_prime(4))   # Output: False
print(is_prime(1))   # Output: False
