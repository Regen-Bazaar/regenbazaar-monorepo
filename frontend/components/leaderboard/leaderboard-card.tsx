"use client"

import { useState } from "react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { MetricCard } from "./metric-card"
import { LeaderboardCard } from "./leaderboard-card"
import { DollarSign, Leaf, Gift, Share2, ShoppingBag, BarChart } from "lucide-react"
import { useBuyerLeaderboard, useSellerLeaderboard, formatCurrency } from "./leaderboard-api"

export default function Leaderboard() {
  const [activeTab, setActiveTab] = useState("buyers")
  const { buyers, loading: buyersLoading, error: buyersError } = useBuyerLeaderboard()
  const { sellers, loading: sellersLoading, error: sellersError } = useSellerLeaderboard()

  if (buyersLoading || sellersLoading) {
    return <div>Loading leaderboard data...</div>
  }

  if (buyersError || sellersError) {
    return <div>Error: {buyersError || sellersError}</div>
  }

  const totalImpactValue = buyers.reduce((sum, buyer) => sum + buyer.totalImpactValue, 0)
  const rebazRewards = buyers.reduce((sum, buyer) => sum + buyer.rebazRewards, 0)
  const totalReferrals = buyers.reduce((sum, buyer) => sum + buyer.referrals, 0)

  const totalRevenue = sellers.reduce((sum, seller) => sum + seller.totalRevenue, 0)
  const productsSold = sellers.reduce((sum, seller) => sum + seller.productsSold, 0)
  const avgImpactValue = sellers.reduce((sum, seller) => sum + seller.avgImpactValue, 0) / sellers.length

  return (
    <div className="container mx-auto py-8">
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold mb-2">RegenBazaar Leaderboard</h1>
        <p className="text-muted-foreground">Recognizing top contributors making a real-world impact</p>
      </div>

      <Tabs defaultValue="buyers" className="w-full" onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-2 mb-8">
          <TabsTrigger value="buyers">Buyers</TabsTrigger>
          <TabsTrigger value="sellers">Sellers</TabsTrigger>
        </TabsList>

        <TabsContent value="buyers">
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-8">
            <MetricCard
              title="Total Impact Value"
              value={formatCurrency(totalImpactValue)}
              description="Cumulative impact value purchased"
              icon={<Leaf className="h-5 w-5" />}
            />
            <MetricCard
              title="$REBAZ Rewards"
              value={formatCurrency(rebazRewards)}
              description="Total rewards earned from staking and purchasing"
              icon={<Gift className="h-5 w-5" />}
            />
            <MetricCard
              title="Total Referrals"
              value={totalReferrals.toString()}
              description="Number of successful referrals made"
              icon={<Share2 className="h-5 w-5" />}
            />
          </div>

          <LeaderboardCard
            title="Top Buyers"
            description="Ranked by total impact value purchased"
            data={buyers}
            type="buyers"
          />
        </TabsContent>

        <TabsContent value="sellers">
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-8">
            <MetricCard
              title="Total Revenue"
              value={formatCurrency(totalRevenue)}
              description="Total revenue from Impact Product sales"
              icon={<DollarSign className="h-5 w-5" />}
            />
            <MetricCard
              title="Products Sold"
              value={productsSold.toString()}
              description="Total number of Impact Products sold"
              icon={<ShoppingBag className="h-5 w-5" />}
            />
            <MetricCard
              title="Avg. Impact Value"
              value={formatCurrency(avgImpactValue)}
              description="Average impact value per product"
              icon={<BarChart className="h-5 w-5" />}
            />
          </div>

          <LeaderboardCard
            title="Top Sellers"
            description="Ranked by total revenue from Impact Product sales"
            data={sellers}
            type="sellers"
          />
        </TabsContent>
      </Tabs>
    </div>
  )
}

