## `IWeswapRouter`






### `factory() → address` (external)





### `WWEMIX() → address` (external)





### `addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) → uint256 amountA, uint256 amountB, uint256 liquidity` (external)





### `addLiquidityWEMIX(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountWEMIXMin, address to, uint256 deadline) → uint256 amountToken, uint256 amountWEMIX, uint256 liquidity` (external)





### `removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) → uint256 amountA, uint256 amountB` (external)





### `removeLiquidityWEMIX(address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountWEMIXMin, address to, uint256 deadline) → uint256 amountToken, uint256 amountWEMIX` (external)





### `removeLiquidityWithPermit(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) → uint256 amountA, uint256 amountB` (external)





### `removeLiquidityWEMIXWithPermit(address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountWEMIXMin, address to, uint256 deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) → uint256 amountToken, uint256 amountWEMIX` (external)





### `swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline) → uint256[] amounts` (external)





### `swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] path, address to, uint256 deadline) → uint256[] amounts` (external)





### `swapExactWEMIXForTokens(uint256 amountOutMin, address[] path, address to, uint256 deadline) → uint256[] amounts` (external)





### `swapTokensForExactWEMIX(uint256 amountOut, uint256 amountInMax, address[] path, address to, uint256 deadline) → uint256[] amounts` (external)





### `swapExactTokensForWEMIX(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline) → uint256[] amounts` (external)





### `swapWEMIXForExactTokens(uint256 amountOut, address[] path, address to, uint256 deadline) → uint256[] amounts` (external)





### `quote(uint256 amountA, uint256 reserveA, uint256 reserveB) → uint256 amountB` (external)





### `getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) → uint256 amountOut` (external)





### `getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) → uint256 amountIn` (external)





### `getAmountsOut(uint256 amountIn, address[] path) → uint256[] amounts` (external)





### `getAmountsIn(uint256 amountOut, address[] path) → uint256[] amounts` (external)






