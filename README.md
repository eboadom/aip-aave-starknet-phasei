# AIP. Aave <> Starknet. Phase I

Implementation of the Aave Improvement Proposal (AIP) payload described and discussed [here](https://governance.aave.com/t/request-for-approval-aave-starkware-phase-i/7145) and approved by the Aave community [here](https://snapshot.org/#/aave.eth/proposal/0x56eb24ad5e2811990899653155caee022a80f3800e51b2b37ecc9254a0a51335).

In order to release the USDC and WETH funds requested for the first payment schedule, the payload updates the implementation of the [AaveCollector](https://etherscan.io/address/0x464c71f6c2f760dda6093dcb91c24c39e5d6e18c) proxy contract containing the treasury of Aave V2 Ethereum. In order to minimise new code, the implementation to be used is the same as the current AAVE token treasury, that can be found [here](https://etherscan.io/address/0xa335e2443b59d11337e9005c9af5bc31f8000714). In addition, the ControllerV2Collector deployed by the payload has also the same code as the controller of the AAVE token treasury [here](https://etherscan.io/address/0x1e506cbb6721b83b1549fa1558332381ffa61a93)

The tests included on [ValidateAIPStarknetPhaseI.sol](./src/test/ValidateAIPStarknetPhaseI.sol) validate:
- The proper lifecycle of the proposal: proposal is created, voted and executed correctly.
- The implementation of the AaveCollector contract is replaced correctly.
- The proxy of the AaveCollector is controlled by the newly deployed ControllerV2Collector. Same layer of indirection as with the AAVE treasury, where the Aave governance Short Executor owns the ControllerV2Collector, and this one is able to transfer() and approve() on the AaveCollector proxy. This is needed because of the transparent proxy pattern used, as the admin of the AaveCollector proxy is the Short Executor, so the `fundsAdmin` can't be the same address.
- Access control on transfer() and approve() functions of both the AaveCollector proxy and the  ControllerV2Collector.
- The recipient of the funds ($100k in USDC and WETH) receives them correctly. 



## Setup
Create a `.env` file following the `.env.example`, adding a Ethereum node URL (Alchemy, Infura)


## Dependencies

```
make update
```

## Compilation

```
make build
```

## Testing

```
make test
```

or for verbose

```
make trace
```
