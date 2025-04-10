"use client"

import { useState, useEffect } from "react"
import { useScaffoldEventHistory } from "../../../regenbazaar/packages/nextjs/hooks/scaffold-eth"
import { Address } from "../../../regenbazaar/packages/nextjs/components/scaffold-eth"
import { Provider, constants } from "starknet"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../../frontend/components/ui/tabs"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "../../../frontend/components/ui/card"
import { Trophy, Leaf, Gift, Share2, DollarSign, ShoppingBag, BarChart, Heart } from "lucide-react"
import LeaderboardMetricCard from "../../components/leaderboard/metric-card"

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

// Format currency values
const formatCurrency = (value: bigint | number) => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(Number(value))
}

const starknetProvider = new Provider({ sequencer: { network: constants.NetworkName.SN_SEPOLIA } })
const REBAZ_ADDRESS = "0x..." // Replace with actual deployed address

export default function LeaderboardPage() {
  const [activeTab, setActiveTab] = useState("buyers")
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
        // Comment out actual Starknet call for now to avoid errors if not set up
        /*
        const events = await starknetProvider.getEvents({
          address: REBAZ_ADDRESS,
          eventKey: "RewardDistributed", // Replace with actual event key from ABI
          fromBlock: { block_number: 0 },
          toBlock: "latest",
          chunk_size: 1000,
        });
        const rewards = events.events.map(event => ({
          recipient: event.data[0], // Adjust based on ABI
          amount: BigInt(event.data[1]),
        }));
        */

        // Use mock data for now
        const rewards = [
          { recipient: "0x1234", amount: BigInt(1000) },
          { recipient: "0x5678", amount: BigInt(750) },
        ]

        setRewardsData(rewards)
      } catch (error) {
        console.error("Failed to fetch Starknet rewards:", error)
        // Set empty array to avoid undefined errors
        setRewardsData([])
      }
      setLoadingStarknet(false)
    }

    fetchStarknetRewards()
  }, [])

  // Handle loading state
  if (loadingCelo || loadingStarknet) {
    return (
      <div className="container mx-auto p-6">
        <div className="flex items-center justify-center h-64">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-lg">Loading leaderboard data...</p>
          </div>
        </div>
      </div>
    )
  }

  // Handle no data state
  if (!purchaseEvents || purchaseEvents.length === 0) {
    return (
      <div className="container mx-auto p-6">
        <div className="text-center p-8 border rounded-lg bg-muted/20">
          <p className="text-lg mb-2">No purchase data available</p>
          <p className="text-muted-foreground">Check back later as users make purchases on the platform.</p>
        </div>
      </div>
    )
  }

  // Process data
  const buyerMap = new Map<string, Buyer>()
  const sellerMap = new Map<string, Seller>()

  // Process purchase events
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

  // Process rewards data
  if (rewardsData && rewardsData.length > 0) {
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
  }

  // Calculate seller averages
  sellerMap.forEach((seller) => {
    seller.averageImpactValue = seller.productsSold > 0 ? Number(seller.totalImpactValueSold) / seller.productsSold : 0
  })

  // Sort buyers and sellers
  const buyers = Array.from(buyerMap.values()).sort((a, b) => Number(b.rwiRankScore - a.rwiRankScore))
  const sellers = Array.from(sellerMap.values()).sort((a, b) => Number(b.totalRevenue - a.totalRevenue))

  // Calculate totals for summary metrics
  const totalImpactValue = buyers.reduce((sum, buyer) => sum + buyer.totalImpactValue, 0n)
  const totalRewardsEarned = buyers.reduce((sum, buyer) => sum + buyer.rewardsEarned, 0n)
  const totalQfRewards = buyers.reduce((sum, buyer) => sum + buyer.qfRewards, 0n)
  const totalReferrals = buyers.reduce((sum, buyer) => sum + buyer.referrals, 0)

  const totalRevenue = sellers.reduce((sum, seller) => sum + seller.totalRevenue, 0n)
  const totalProductsSold = sellers.reduce((sum, seller) => sum + seller.productsSold, 0)
  const avgImpactValue =
    sellers.length > 0
      ? Number(sellers.reduce((sum, seller) => sum + BigInt(Math.round(seller.averageImpactValue)), 0n)) /
        sellers.length
      : 0

  return (
    <div className="container mx-auto py-8 px-4">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">RegenBazaar Leaderboard</h1>
        <p className="text-muted-foreground max-w-2xl mx-auto">
          Recognizing top contributors making a real-world impact through the RegenBazaar platform
        </p>
      </div>

      <Tabs defaultValue="buyers" className="w-full" onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-2 mb-8">
          <TabsTrigger value="buyers">Buyers</TabsTrigger>
          <TabsTrigger value="sellers">Sellers</TabsTrigger>
        </TabsList>

        <TabsContent value="buyers">
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
            <LeaderboardMetricCard
              title="Total Impact Value"
              value={formatCurrency(totalImpactValue)}
              description="Cumulative impact value purchased"
              icon={<Leaf className="h-5 w-5" />}
            />
            <LeaderboardMetricCard
              title="$REBAZ Rewards"
              value={formatCurrency(totalRewardsEarned)}
              description="Total rewards earned from staking and purchasing"
              icon={<Gift className="h-5 w-5" />}
            />
            <LeaderboardMetricCard
              title="QF Rewards Distributed"
              value={formatCurrency(totalQfRewards)}
              description="Total rewards distributed to RWI projects"
              icon={<Heart className="h-5 w-5" />}
            />
            <LeaderboardMetricCard
              title="Total Referrals"
              value={totalReferrals.toString()}
              description="Number of successful referrals made"
              icon={<Share2 className="h-5 w-5" />}
            />
          </div>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Trophy className="h-5 w-5 text-amber-500" />
                Top Buyers
              </CardTitle>
              <CardDescription>Ranked by RWI score (impact value + rewards)</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-3 px-4">Rank</th>
                      <th className="text-left py-3 px-4">Buyer</th>
                      <th className="text-right py-3 px-4">Total Impact Value</th>
                      <th className="text-right py-3 px-4">$REBAZ Rewards</th>
                      <th className="text-right py-3 px-4">RWI Rank Score</th>
                      <th className="text-right py-3 px-4">QF Rewards</th>
                      <th className="text-right py-3 px-4">Referrals</th>
                    </tr>
                  </thead>
                  <tbody>
                    {buyers.slice(0, 10).map((buyer, index) => (
                      <tr key={buyer.address} className="hover:bg-muted/50 border-b">
                        <td className="py-3 px-4 text-center">{index + 1}</td>
                        <td className="py-3 px-4">
                          <Address address={buyer.address} size="sm" />
                        </td>
                        <td className="py-3 px-4 text-right">{formatCurrency(buyer.totalImpactValue)}</td>
                        <td className="py-3 px-4 text-right">{formatCurrency(buyer.rewardsEarned)}</td>
                        <td className="py-3 px-4 text-right">{formatCurrency(buyer.rwiRankScore)}</td>
                        <td className="py-3 px-4 text-right">{formatCurrency(buyer.qfRewards)}</td>
                        <td className="py-3 px-4 text-right">{buyer.referrals}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="sellers">
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-8">
            <LeaderboardMetricCard
              title="Total Revenue"
              value={formatCurrency(totalRevenue)}
              description="Total revenue from Impact Product sales"
              icon={<DollarSign className="h-5 w-5" />}
            />
            <LeaderboardMetricCard
              title="Products Sold"
              value={totalProductsSold.toString()}
              description="Total number of Impact Products sold"
              icon={<ShoppingBag className="h-5 w-5" />}
            />
            <LeaderboardMetricCard
              title="Avg. Impact Value"
              value={formatCurrency(avgImpactValue)}
              description="Average impact value per product"
              icon={<BarChart className="h-5 w-5" />}
            />
          </div>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Trophy className="h-5 w-5 text-amber-500" />
                Top Sellers
              </CardTitle>
              <CardDescription>Ranked by total revenue from Impact Product sales</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-3 px-4">Rank</th>
                      <th className="text-left py-3 px-4">Seller</th>
                      <th className="text-right py-3 px-4">Total Revenue</th>
                      <th className="text-right py-3 px-4">Products Sold</th>
                      <th className="text-right py-3 px-4">Avg Impact Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sellers.slice(0, 10).map((seller, index) => (
                      <tr key={seller.address} className="hover:bg-muted/50 border-b">
                        <td className="py-3 px-4 text-center">{index + 1}</td>
                        <td className="py-3 px-4">
                          <Address address={seller.address} size="sm" />
                        </td>
                        <td className="py-3 px-4 text-right">{formatCurrency(seller.totalRevenue)}</td>
                        <td className="py-3 px-4 text-right">{seller.productsSold}</td>
                        <td className="py-3 px-4 text-right">{formatCurrency(seller.averageImpactValue)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

