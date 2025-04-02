import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Trophy } from "lucide-react"
import { formatCurrency } from "./leaderboard-api"
import type { BuyerData, SellerData } from "./leaderboard-api"

type LeaderboardCardProps = {
  title: string
  description: string
  data: BuyerData[] | SellerData[]
  type: "buyers" | "sellers"
}

export function LeaderboardCard({ title, description, data, type }: LeaderboardCardProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Trophy className="h-5 w-5 text-amber-500" />
          {title}
        </CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {type === "buyers"
            ? // Buyers leaderboard
              (data as BuyerData[]).map((buyer) => (
                <div key={buyer.id} className="flex items-center justify-between p-4 rounded-lg border">
                  <div className="flex items-center gap-4">
                    <div className="flex items-center justify-center w-8 h-8 rounded-full bg-muted font-semibold">
                      {buyer.rank}
                    </div>
                    <Avatar>
                      <AvatarImage src={buyer.avatar} alt={buyer.name} />
                      <AvatarFallback>{buyer.name.substring(0, 2)}</AvatarFallback>
                    </Avatar>
                    <div>
                      <div className="font-medium">{buyer.name}</div>
                      <div className="text-sm text-muted-foreground">RWI Rank: {buyer.rwiRank}</div>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-4 text-sm md:grid-cols-4">
                    <div className="hidden md:block">
                      <div className="font-medium">{formatCurrency(buyer.totalImpactValue)}</div>
                      <div className="text-xs text-muted-foreground">Impact Value</div>
                    </div>
                    <div className="hidden md:block">
                      <div className="font-medium">{formatCurrency(buyer.rebazRewards)}</div>
                      <div className="text-xs text-muted-foreground">$REBAZ Rewards</div>
                    </div>
                    <div>
                      <div className="font-medium">{formatCurrency(buyer.rewardsDistributed)}</div>
                      <div className="text-xs text-muted-foreground">Distributed</div>
                    </div>
                    <div>
                      <div className="font-medium">{buyer.referrals}</div>
                      <div className="text-xs text-muted-foreground">Referrals</div>
                    </div>
                  </div>
                </div>
              ))
            : // Sellers leaderboard
              (data as SellerData[]).map((seller) => (
                <div key={seller.id} className="flex items-center justify-between p-4 rounded-lg border">
                  <div className="flex items-center gap-4">
                    <div className="flex items-center justify-center w-8 h-8 rounded-full bg-muted font-semibold">
                      {seller.rank}
                    </div>
                    <Avatar>
                      <AvatarImage src={seller.avatar} alt={seller.name} />
                      <AvatarFallback>{seller.name.substring(0, 2)}</AvatarFallback>
                    </Avatar>
                    <div>
                      <div className="font-medium">{seller.name}</div>
                      <div className="text-sm text-muted-foreground">Seller</div>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-4 text-sm md:grid-cols-3">
                    <div className="hidden md:block">
                      <div className="font-medium">{formatCurrency(seller.totalRevenue)}</div>
                      <div className="text-xs text-muted-foreground">Revenue</div>
                    </div>
                    <div>
                      <div className="font-medium">{seller.productsSold}</div>
                      <div className="text-xs text-muted-foreground">Products Sold</div>
                    </div>
                    <div>
                      <div className="font-medium">{formatCurrency(seller.avgImpactValue)}</div>
                      <div className="text-xs text-muted-foreground">Avg. Impact</div>
                    </div>
                  </div>
                </div>
              ))}
        </div>
      </CardContent>
    </Card>
  )
}

