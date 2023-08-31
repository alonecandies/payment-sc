# payment-sub
## Tasks
- Write tests
- Write fallback
- Refactor save plans using mapping instead of array
- Optimize gas used (storage, instructions, loop)

## Test cases
- Proxy contract: upgrade without change in storage and contract address
- Set right stable address
- Set plans
- Get right plans
- sub => right expiry + money
- sub when not enough money
- double sub
- extends => increase expiry + money
- double extends => double increase expiry + money
- enable and disable autorenew
- withdraw money
  