import { Address, DeployFunction } from "hardhat-deploy/types";
// const hre = require("hardhat");
// const { ethers } = require("ethers");
import ethers from "ethers"
import hre from 'hardhat';
import {
  abi as FACTORY_ABI,
  bytecode as FACTORY_BYTECODE,
} from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json'
import {
  abi as SWAP_ROUTER_ABI,
  bytecode as SWAP_ROUTER_BYTECODE,
} from '@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json'
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { constants } from "ethers";
import { tokenBABI, tokenAABI, NonfungiblePositionManagerABI, uniswapV3RouterABI, uniswapPoolABI } from "./abi"



// const toNumber = ethers.utils.formatEther
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const POO = "0xCe3eb2c15ceCC8547B5390FB47d5aBAf3d7624db"
const poolAddress = "0xcbb503fcc538ea591fd8383e0324cd03542df6ac"


const func = async () => {
  // @ts-ignore
  const [deployer] = await hre.ethers.getSigners()

  // const factory = await deployments.deploy("UniV3Factory", {
  //   from: deployer.address,
  //   contract: {
  //     bytecode: FACTORY_BYTECODE,
  //     abi: FACTORY_ABI
  //   },
  // })
  // await deployments.deploy("UniV3SwapRouter", {
  //   from: deployer.address,
  //   contract: {
  //     abi: SWAP_ROUTER_ABI,
  //     bytecode: SWAP_ROUTER_BYTECODE
  //   },
  //   args: [factory.address, constants.AddressZero]
  //   // 上面是部署合约的参数，第一个参数为factory地址，第二个为WETH地址，这里为了图方便就直接用0地址啦😁
  // })



  // @ts-ignore
  const NonfungiblePositionManagerExamples = await hre.ethers.getContractFactory(
    "NonfungiblePositionManager"
  )
  const NonfungiblePositionManager = await NonfungiblePositionManagerExamples.deploy(
    "0x1F98431c8aD98523631AE4a59f267346ea31F984", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")

  console.log(NonfungiblePositionManager)
  return;


  // // @ts-ignore
  // const SwapRouterExamples = await hre.ethers.getContractFactory(
  //   "SwapRouter"
  // )
  // const SwapRouter = await SwapRouterExamples.deploy()

  // console.log(SwapRouter)
  // // await mint(SwapRouter)


  // // }

  // // const mint = async (SwapRouter:string) => {
  // // @ts-ignore
  // const accounts = await hre.ethers.getSigners();
  // const signer = accounts[0];
  // const signer2 = accounts[0];

  // // -------------------将池子兑换空---------------------------
  // const tokenA = new ethers.Contract(WETH, tokenAABI, signer)
  // const tokenB = new ethers.Contract(POO, tokenBABI, signer)
  // const uniswapV3Router = new ethers.Contract(SwapRouter, uniswapV3RouterABI, signer)
  // const uniswapPool = new ethers.Contract(poolAddress, uniswapPoolABI, signer)
  // await tokenA.deposit({ value: ethers.utils.parseEther("100") });
  // console.log('signer on tokenA WETH balanace', ethers.utils.formatEther(await tokenA.balanceOf(signer.address)))
  // console.log('signer on tokenB POO balanace', ethers.utils.formatEther(await tokenB.balanceOf(signer.address)))
  // // signer给目标地址 授权足够的额度
  // await tokenA.approve(SwapRouter, "100000000000000000000000000000000000000")
  // const poolBalanceWETHBeforeSwap = Number(toNumber(await tokenA.balanceOf(poolAddress)))
  // const poolBalancePOOBeforeSwap = Number(toNumber(await tokenB.balanceOf(poolAddress)))
  // console.log("pool 里 WETH tokenA余额:", poolBalanceWETHBeforeSwap)
  // console.log("pool 里 POO tokenB余额:", poolBalancePOOBeforeSwap)
  // const slot0_1 = await uniswapPool.slot0();
  // // console.log(slot0_1);
  // console.log('最初 pool sqrtPriceX96', toNumber(slot0_1[0]), (slot0_1[1]));
  // console.log('最初 uniswapPool.liquidity', toNumber(await uniswapPool.liquidity()));



  // // 交易
  // await uniswapV3Router.exactInputSingle([
  //   WETH,
  //   POO,
  //   10000,//fee
  //   signer.address,
  //   4815162342,//deadline
  //   ethers.utils.parseEther("0.01"),//amountIn
  //   ethers.utils.parseEther("100"),//amountOutMinimum
  //   0//priceLimit
  // ]);
  // console.log('----------------------------------------------------------------')
  // // 实际只消耗掉4个左右ETH
  // const signerBalance = await tokenA.balanceOf(signer.address)
  // console.log('signer on tokenA.balanceOf afterexactInput swap', toNumber(await tokenA.balanceOf(signer.address)))
  // const poolBalanceWETHAfterSwap = Number(toNumber(await tokenA.balanceOf(poolAddress)))
  // const poolBalancePOOAfterSwap = Number(toNumber(await tokenB.balanceOf(poolAddress)))
  // console.log("after swap: pool info WETH tokenA:", poolBalanceWETHAfterSwap)
  // console.log("after swap: pool info POO tokenB:", poolBalancePOOAfterSwap)
  // console.log('WETH diff', poolBalanceWETHAfterSwap - poolBalanceWETHBeforeSwap)
  // // 少了67亿个POO
  // console.log('POO diff', poolBalancePOOAfterSwap - poolBalancePOOBeforeSwap)

  // const slot0 = await uniswapPool.slot0();
  // console.log(slot0);
  // console.log('交易后 pool sqrtPriceX96', toNumber(slot0[0]));
  // console.log('uniswapPool.liquidity', toNumber(await uniswapPool.liquidity()));
  // // ---------------mint一个流动性,注入流动性
  // console.log('----------------------------------------------------------------')

  // console.log("account1 tokenA balance:", toNumber(await tokenA.balanceOf(signer.address)))
  // console.log("account1 tokenB balance:", toNumber(await tokenB.balanceOf(signer.address)))


}
func()
// export default func;