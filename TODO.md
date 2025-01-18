- deploy a classic ERC20 outside the diamond
- update the multisig facet to be initialized with cutsom parameters :
    - address of the ERC20 
    - validation treshold percentage


Other :
-remove ownership stuff bc useless if it is the diamond itself
- replace requires by custom revert errors
- add best practices 