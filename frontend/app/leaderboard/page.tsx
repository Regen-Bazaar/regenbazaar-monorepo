"use client"

import { useScaffoldEventHistory } from "../../../regenbazaar/packages/nextjs/hooks/scaffold-eth"
import { Address } from "../../../regenbazaar/packages/nextjs/components/scaffold-eth"

// Define types for Buyer and Seller based on required metrics
type Buyer = {
  address: string
  totalImpactValue: bigint
}

type Seller = {
  address: string
  totalRevenue: bigint
  productsSold: number
  totalImpactValueSold: bigint
  averageImpactValue: number
}

export default function LeaderboardPage() {
  // Fetch purchase events from the RegenBabazaMarketPlace contract
  const { data: purchaseEvents, isLoading } = useScaffoldEventHistory({
    contractName: "RegenBabazaMarketPlace",
    eventName: "Purchase",
    fromBlock: 0n,
    blockData: false,
    transactionData: false,
    receiptData: false,
  })

  // Handle loading and no-data states
  if (isLoading) {
    return <div className="text-center p-4 text-lg">Loading...</div>
  }

  if (!purchaseEvents || purchaseEvents.length === 0) {
    return <div className="text-center p-4 text-lg">No purchase data available</div>
  }

  // Process events to calculate metrics
  const buyerMap = new Map<string, Buyer>()
  const sellerMap = new Map<string, Seller>()

  for (const event of purchaseEvents) {
    // Assuming event.args contains buyer, seller, impactValue, and price
    const { buyer, seller, impactValue, price } = event.args as {
      buyer: string
      seller: string
      impactValue: bigint
      price: bigint
    }

    // Update buyer metrics
    if (buyerMap.has(buyer)) {
      const b = buyerMap.get(buyer)!
      b.totalImpactValue += impactValue
    } else {
      buyerMap.set(buyer, { address: buyer, totalImpactValue: impactValue })
    }

    // Update seller metrics
    if (sellerMap.has(seller)) {
      const s = sellerMap.get(seller)!
      s.totalRevenue += price
      s.productsSold += 1
      s.totalImpactValueSold += impactValue
    } else {
      sellerMap.set(seller, {
        address: seller,
        totalRevenue: price,
        productsSold: 1,
        totalImpactValueSold: impactValue,
        averageImpactValue: 0, // Calculated later
      })
    }
  }

  // Calculate average impact value for sellers
  sellerMap.forEach((seller) => {
    seller.averageImpactValue = seller.productsSold > 0 ? Number(seller.totalImpactValueSold) / seller.productsSold : 0
  })

  // Convert maps to arrays and sort
  const buyers = Array.from(buyerMap.values()).sort((a, b) => Number(b.totalImpactValue - a.totalImpactValue))
  const sellers = Array.from(sellerMap.values()).sort((a, b) => Number(b.totalRevenue - a.totalRevenue))

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-4xl font-bold mb-8 text-center">RegenBazaar Leaderboard</h1>

      {/* Buyers Section */}
      <section className="mb-12">
        <h2 className="text-2xl font-semibold mb-4 text-gray-800">Top Buyers</h2>
        <div className="overflow-x-auto shadow-md rounded-lg">
          <table className="min-w-full bg-white border border-gray-200">
            <thead className="bg-gray-100">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-medium text-gray-700">Rank</th>
                <th className="px-6 py-3 text-left text-sm font-medium text-gray-700">Buyer</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-700">Total Impact Value</th>
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
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Sellers Section */}
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

