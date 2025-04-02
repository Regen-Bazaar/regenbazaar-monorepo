"use client"

import { useState, useEffect } from "react"

// Types for our leaderboard data
export type BuyerData = {
  id: string
  rank: number
  name: string
  avatar: string
  totalImpactValue: number
  rebazRewards: number
  rwiRank: number
  rewardsDistributed: number
  referrals: number
}

export type SellerData = {
  id: string
  rank: number
  name: string
  avatar: string
  totalRevenue: number
  productsSold: number
  avgImpactValue: number
}

// Hook to fetch buyer leaderboard data
export function useBuyerLeaderboard() {
  const [buyers, setBuyers] = useState<BuyerData[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchBuyerData() {
      try {
        setLoading(true)
        // In a real implementation, this would be an API call
        // const response = await fetch('/api/leaderboard/buyers');
        // const data = await response.json();

        // For now, we'll use mock data
        const mockBuyers: BuyerData[] = [
          {
            id: "1",
            rank: 1,
            name: "Alex Johnson",
            avatar: "/placeholder.svg?height=40&width=40",
            totalImpactValue: 12500,
            rebazRewards: 750,
            rwiRank: 1,
            rewardsDistributed: 2500,
            referrals: 15,
          },
          {
            id: "2",
            rank: 2,
            name: "Jamie Smith",
            avatar: "/placeholder.svg?height=40&width=40",
            totalImpactValue: 10200,
            rebazRewards: 620,
            rwiRank: 3,
            rewardsDistributed: 1800,
            referrals: 12,
          },
          {
            id: "3",
            rank: 3,
            name: "Taylor Wilson",
            avatar: "/placeholder.svg?height=40&width=40",
            totalImpactValue: 9800,
            rebazRewards: 580,
            rwiRank: 2,
            rewardsDistributed: 2100,
            referrals: 10,
          },
          {
            id: "4",
            rank: 4,
            name: "Morgan Lee",
            avatar: "/placeholder.svg?height=40&width=40",
            totalImpactValue: 8500,
            rebazRewards: 510,
            rwiRank: 4,
            rewardsDistributed: 1500,
            referrals: 8,
          },
          {
            id: "5",
            rank: 5,
            name: "Casey Brown",
            avatar: "/placeholder.svg?height=40&width=40",
            totalImpactValue: 7200,
            rebazRewards: 430,
            rwiRank: 5,
            rewardsDistributed: 1200,
            referrals: 6,
          },
        ]

        setBuyers(mockBuyers)
        setError(null)
      } catch (err) {
        setError("Failed to fetch buyer leaderboard data")
        console.error(err)
      } finally {
        setLoading(false)
      }
    }

    fetchBuyerData()
  }, [])

  return { buyers, loading, error }
}

// Hook to fetch seller leaderboard data
export function useSellerLeaderboard() {
  const [sellers, setSellers] = useState<SellerData[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchSellerData() {
      try {
        setLoading(true)
        // In a real implementation, this would be an API call
        // const response = await fetch('/api/leaderboard/sellers');
        // const data = await response.json();

        // For now, we'll use mock data
        const mockSellers: SellerData[] = [
          {
            id: "1",
            rank: 1,
            name: "EcoSolutions Inc.",
            avatar: "/placeholder.svg?height=40&width=40",
            totalRevenue: 45000,
            productsSold: 120,
            avgImpactValue: 375,
          },
          {
            id: "2",
            rank: 2,
            name: "Green Future Co.",
            avatar: "/placeholder.svg?height=40&width=40",
            totalRevenue: 38000,
            productsSold: 95,
            avgImpactValue: 400,
          },
          {
            id: "3",
            rank: 3,
            name: "Sustainable Goods",
            avatar: "/placeholder.svg?height=40&width=40",
            totalRevenue: 32000,
            productsSold: 85,
            avgImpactValue: 376,
          },
          {
            id: "4",
            rank: 4,
            name: "EarthFirst Products",
            avatar: "/placeholder.svg?height=40&width=40",
            totalRevenue: 28000,
            productsSold: 70,
            avgImpactValue: 400,
          },
          {
            id: "5",
            rank: 5,
            name: "Regenerative Designs",
            avatar: "/placeholder.svg?height=40&width=40",
            totalRevenue: 25000,
            productsSold: 65,
            avgImpactValue: 384,
          },
        ]

        setSellers(mockSellers)
        setError(null)
      } catch (err) {
        setError("Failed to fetch seller leaderboard data")
        console.error(err)
      } finally {
        setLoading(false)
      }
    }

    fetchSellerData()
  }, [])

  return { sellers, loading, error }
}

// Format currency values
export const formatCurrency = (value: number) => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(value)
}

