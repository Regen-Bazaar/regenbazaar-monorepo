"use client"

import { useState, useEffect } from "react"
import { useScaffoldEventHistory } from "../../../regenbazaar/packages/nextjs/hooks/scaffold-eth"
import { Address } from "../../../regenbazaar/packages/nextjs/components/scaffold-eth"
import { Provider, constants } from "starknet"

type Buyer = {
  address: string
  totalImpactValue: bigint
  rewardsEarned: bigint
  rwiRankScore: bigint
  qfRewards: bigint // Placeholder until QF contract provided
  referrals: number // Placeholder until referral contract provided
}

type Seller = {
  address: string
  totalRevenue: bigint
  productsSold: number
  totalImpactValueSold: bigint
  averageImpactValue: number
}

const starknetProvider = new Provider({ sequencer: { network: constants.NetworkName.SN_SEPOLIA } })
const REBAZ_ADDRESS = "0x..." // Replace with actual deployed address

export default function LeaderboardPage() {
  const { data: purchaseEvents, isLoading: loadingCelo } = useScaffoldEventHistory({
    contractName: "RegenBazaar",
    eventName: "ListingPurchased",
    fromBlock: 0n,
  })

  const [rewardsData, setRewardsData] = useState<Array<{ recipient: string; amount: bigint }>>([])
  const [loadingStarknet, setLoadingStarknet] = useState(true)

  useEffect(() => {
    const fetchStarknetRewards = async () => {
      try {
        const events = await starknetProvider.getEvents({
          address: REBAZ_ADDRESS,
          eventKey: "RewardDistributed", // Replace with actual event key from ABI
          fromBlock: { block_number: 0 },
          toBlock: "latest",
          chunk_size: 1000,
        })
        const rewards = events.events.map((event) => ({
          recipient: event.data[0], // Adjust based on ABI
          amount: BigInt(event.data[1]),
        }))
        setRewardsData(rewards)
      } catch (error) {
        console.error("Failed to fetch Starknet rewards:", error)
      }
      setLoadingStarknet(false)
    }
    fetchStarknetRewards()
  }, [])

  if (loadingCelo || loadingStarknet) return <div className="text-center p-4 text-lg">Loading...</div>
  if (!purchaseEvents || purchaseEvents.length === 0) return <div className="text-center p-4 text-lg">No data</div>

  const buyerMap = new Map<string, Buyer>()
  const sellerMap = new Map<string, Seller>()

  for (const event of purchaseEvents) {
    const { buyer, seller, totalPrice, quantity, sellerShare } = event.args as {
      buyer: string
      seller: string
      totalPrice: bigint
      quantity: bigint
      sellerShare: bigint
    }

    if (buyerMap.has(buyer)) {
      const b = buyerMap.get(buyer)!
      b.totalImpactValue += totalPrice
      b.rwiRankScore = b.totalImpactValue + b.rewardsEarned
    } else {
      buyerMap.set(buyer, {
        address: buyer,
        totalImpactValue: totalPrice,
        rewardsEarned: 0n,
        rwiRankScore: totalPrice,
        qfRewards: 0n,
        referrals: 0,
      })
    }

    if (sellerMap.has(seller)) {
      const s = sellerMap.get(seller)!
      s.totalRevenue += sellerShare
      s.productsSold += Number(quantity)
      s.totalImpactValueSold += totalPrice
    } else {
      sellerMap.set(seller, {
        address: seller,
        totalRevenue: sellerShare,
        productsSold: Number(quantity),
        totalImpactValueSold: totalPrice,
        averageImpactValue: 0,
      })
    }
  }

  for (const reward of rewardsData) {
    const b = buyerMap.get(reward.recipient) || {
      address: reward.recipient,
      totalImpactValue: 0n,
      rewardsEarned: 0n,
      rwiRankScore: 0n,
      qfRewards: 0n,
      referrals: 0,
    }
    b.rewardsEarned += reward.amount
    b.rwiRankScore = b.totalImpactValue + b.rewardsEarned
    buyerMap.set(reward.recipient, b)
  }

  sellerMap.forEach((seller) => {
    seller.averageImpactValue = seller.productsSold > 0 ? Number(seller.totalImpactValueSold) / seller.productsSold : 0
  })

  const buyers = Array.from(buyerMap.values()).sort((a, b) => Number(b.rwiRankScore - a.rwiRankScore))
  const sellers = Array.from(sellerMap.values()).sort((a, b) => Number(b.totalRevenue - a.totalRevenue))

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-4xl font-bold mb-8 text-center">RegenBazaar Leaderboard</h1>

      <section className="mb-12">
        <h2 className="text-2xl font-semibold mb-4 text-gray-800">Top Buyers</h2>
        <div className="overflow-x-auto shadow-md rounded-lg">
          <table className="min-w-full bg-white border border-gray-200">
            <thead className="bg-gray-100">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-medium text-gray-700">Rank</th>
                <th className="px-6 py-3 text-left text-sm font-medium text-gray-700">Buyer</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">Total Impact Value</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">$REBAZ Rewards</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">RWI Rank Score</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">QF Rewards</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">Referrals</th>
              </tr>
            </thead>
            <tbody>
              {buyers.slice(0, 10).map((buyer, index) => (
                <tr key={buyer.address} className="hover:bg-gray-50 border-b">
                  <td className="px-6 py-4 text-center">{index + 1}</td>
                  <td className="px-6 py-4">
                    <Address address={buyer.address} size="sm" />
                  </td>
                  <td className="px-6 py-4 text-right">{buyer.totalImpactValue.toString()}</td>
                  <td className="px-6 py-4 text-right">{buyer.rewardsEarned.toString()}</td>
                  <td className="px-6 py-4 text-right">{buyer.rwiRankScore.toString()}</td>
                  <td className="px-6 py-4 text-right">{buyer.qfRewards.toString()}</td>
                  <td className="px-6 py-4 text-right">{buyer.referrals}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-2xl font-semibold mb-4 text-gray-800">Top Sellers</h2>
        <div className="overflow-x-auto shadow-md rounded-lg">
          <table className="min-w-full bg-white border border-gray-200">
            <thead className="bg-gray-100">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-medium text-gray-700">Rank</th>
                <th className="px-6 py-3 text-left text-sm font-medium text-gray-700">Seller</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">Total Revenue</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">Products Sold</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">Avg Impact Value</th>
              </tr>
            </thead>
            <tbody>
              {sellers.slice(0, 10).map((seller, index) => (
                <tr key={seller.address} className="hover:bg-gray-50 border-b">
                  <td className="px-6 py-4 text-center">{index + 1}</td>
                  <td className="px-6 py-4">
                    <Address address={seller.address} size="sm" />
                  </td>
                  <td className="px-6 py-4 text-right">{seller.totalRevenue.toString()}</td>
                  <td className="px-6 py-4 text-right">{seller.productsSold}</td>
                  <td className="px-6 py-4 text-right">{seller.averageImpactValue.toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}

