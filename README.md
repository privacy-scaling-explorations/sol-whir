<h1 align="center">(Sol) WHIR 🌪️</h1>

Solidity libraries and contracts for verifying [WHIR](https://eprint.iacr.org/2024/1586) proofs on the EVM.

# Usage

You can generate EVM compatible WHIR proofs using the [feat/evm-verifier](https://github.com/dmpierre/whir/tree/feat/evm-verifier) branch from this [fork](https://github.com/dmpierre/whir) - see [this test](https://github.com/dmpierre/whir/blob/a3c91cea69c505198673775f9a273e1a3d75ef82/src/whir/mod.rs#L196). You can still try this implementation out of the box as we included an example proof in this repo, located in `test/data/whir`.

Install and run tests:

```bash
$ git clone git@github.com:privacy-scaling-explorations/sol-whir.git 
$ cd sol-whir
$ forge test --via-ir
```


To run an actual transaction verifying a whir proof, setup a `.env` following the provided `.example.env` file. Then:

```bash
$ anvil
$ forge script script/Verify.s.sol --via-ir --tc VerifyScript --rpc-url http://localhost:8545 --broadcast
```
