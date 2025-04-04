"use client"

import { useState } from "react"
import { Search, Filter, ShoppingCart, Star, User, ChevronLeft } from "lucide-react"

// Type definitions
type Product = {
  id: string
  name: string
  description: string
  price: number
  impactValue: number
  seller: {
    id: string
    name: string
    rating: number
  }
  image: string
  category: string
  tags: string[]
}

type Seller = {
  id: string
  name: string
  rating: number
  products: Product[]
}

// Mock data
const mockProducts: Product[] = [
  {
    id: "1",
    name: "Organic Cotton T-Shirt",
    description: "Fair trade organic cotton t-shirt with low water footprint",
    price: 29.99,
    impactValue: 45,
    seller: {
      id: "seller1",
      name: "EcoFashion Co",
      rating: 4.8,
    },
    image: "/placeholder-tshirt.jpg",
    category: "Apparel",
    tags: ["organic", "fair-trade", "sustainable"],
  },
  {
    id: "2",
    name: "Bamboo Toothbrush",
    description: "Biodegradable bamboo toothbrush with replaceable heads",
    price: 7.99,
    impactValue: 32,
    seller: {
      id: "seller2",
      name: "GreenLiving Essentials",
      rating: 4.6,
    },
    image: "/placeholder-toothbrush.jpg",
    category: "Personal Care",
    tags: ["zero-waste", "biodegradable"],
  },
  {
    id: "3",
    name: "Solar Charger",
    description: "Portable solar charger for phones and small devices",
    price: 49.99,
    impactValue: 78,
    seller: {
      id: "seller3",
      name: "SunPower Tech",
      rating: 4.9,
    },
    image: "/placeholder-solar.jpg",
    category: "Electronics",
    tags: ["renewable", "energy-efficient"],
  },
  {
    id: "4",
    name: "Reusable Water Bottle",
    description: "Stainless steel insulated water bottle",
    price: 24.99,
    impactValue: 56,
    seller: {
      id: "seller1",
      name: "EcoFashion Co",
      rating: 4.8,
    },
    image: "/placeholder-bottle.jpg",
    category: "Home",
    tags: ["reusable", "plastic-free"],
  },
]

const mockSellers: Seller[] = [
  {
    id: "seller1",
    name: "EcoFashion Co",
    rating: 4.8,
    products: mockProducts.filter(p => p.seller.id === "seller1"),
  },
  {
    id: "seller2",
    name: "GreenLiving Essentials",
    rating: 4.6,
    products: mockProducts.filter(p => p.seller.id === "seller2"),
  },
  {
    id: "seller3",
    name: "SunPower Tech",
    rating: 4.9,
    products: mockProducts.filter(p => p.seller.id === "seller3"),
  },
]

// Helper functions
const formatCurrency = (value: number) => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value)
}

const MarketplaceGallery = () => {
  const [activeTab, setActiveTab] = useState<"products" | "sellers">("products")
  const [searchQuery, setSearchQuery] = useState("")
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)
  const [selectedSeller, setSelectedSeller] = useState<Seller | null>(null)

  // Get unique categories
  const categories = Array.from(new Set(mockProducts.map(p => p.category)))

  // Filter products
  const filteredProducts = mockProducts.filter(product => {
    const matchesSearch = product.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
                         product.description.toLowerCase().includes(searchQuery.toLowerCase())
    const matchesCategory = !selectedCategory || product.category === selectedCategory
    return matchesSearch && matchesCategory
  })

  return (
    <div className="container mx-auto py-8 px-4">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">Impact Marketplace</h1>
        <p className="text-gray-500 max-w-2xl mx-auto">
          Discover and purchase products that create positive real-world impact
        </p>
      </div>

      {/* Search and Filter */}
      <div className="flex flex-col md:flex-row gap-4 mb-8">
        <div className="relative flex-1">
          <div className="absolute left-3 top-1/2 -translate-y-1/2">
            <Search className="h-4 w-4 text-gray-400" />
          </div>
          <input
            type="text"
            placeholder="Search products..."
            className="pl-10 pr-4 py-2 w-full rounded-md border border-gray-300 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div className="flex gap-2">
          <div className="relative">
            <div className="absolute left-3 top-1/2 -translate-y-1/2">
              <Filter className="h-4 w-4 text-gray-400" />
            </div>
            <select
              className="pl-10 pr-8 py-2 rounded-md border border-gray-300 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
              value={selectedCategory || ""}
              onChange={(e) => setSelectedCategory(e.target.value || null)}
            >
              <option value="">All Categories</option>
              {categories.map(category => (
                <option key={category} value={category}>{category}</option>
              ))}
            </select>
          </div>
          <button
            className="px-4 py-2 rounded-md border border-gray-300 bg-white text-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent"
            onClick={() => {
              setSearchQuery("")
              setSelectedCategory(null)
            }}
          >
            Clear
          </button>
        </div>
      </div>

      {selectedSeller ? (
        <div className="mb-8">
          <div className="flex items-center gap-4 mb-6">
            <button 
              className="p-2 rounded-full hover:bg-gray-100"
              onClick={() => setSelectedSeller(null)}
            >
              <ChevronLeft className="h-5 w-5" />
            </button>
            <div>
              <h2 className="text-2xl font-bold">{selectedSeller.name}</h2>
              <div className="flex items-center gap-1 text-gray-500">
                <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
                <span>{selectedSeller.rating}</span>
              </div>
            </div>
          </div>

          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {selectedSeller.products.map(product => (
              <ProductCard 
                key={product.id} 
                product={product} 
                onSellerClick={() => {}}
              />
            ))}
          </div>
        </div>
      ) : (
        <div className="w-full">
          {/* Custom Tabs */}
          <div className="flex border-b mb-8">
            <button
              className={`px-4 py-2 font-medium ${activeTab === "products" ? "border-b-2 border-green-500 text-green-600" : "text-gray-500"}`}
              onClick={() => setActiveTab("products")}
            >
              Products
            </button>
            <button
              className={`px-4 py-2 font-medium ${activeTab === "sellers" ? "border-b-2 border-green-500 text-green-600" : "text-gray-500"}`}
              onClick={() => setActiveTab("sellers")}
            >
              Sellers
            </button>
          </div>

          {activeTab === "products" ? (
            <div>
              {filteredProducts.length === 0 ? (
                <div className="text-center p-8 border rounded-lg bg-gray-50">
                  <p className="text-lg mb-2">No products found</p>
                  <p className="text-gray-500">Try adjusting your search or filters</p>
                </div>
              ) : (
                <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                  {filteredProducts.map(product => (
                    <ProductCard 
                      key={product.id} 
                      product={product} 
                      onSellerClick={() => setSelectedSeller(mockSellers.find(s => s.id === product.seller.id)!)}
                    />
                  ))}
                </div>
              )}
            </div>
          ) : (
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              {mockSellers.map(seller => (
                <div key={seller.id} className="border rounded-lg overflow-hidden hover:shadow-md transition-shadow">
                  <div className="p-6">
                    <div className="flex justify-between items-start mb-2">
                      <h3 className="text-xl font-semibold">{seller.name}</h3>
                      <div className="flex items-center gap-1">
                        <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
                        <span>{seller.rating}</span>
                      </div>
                    </div>
                    <p className="text-gray-500 mb-4">{seller.products.length} products listed</p>
                    <div className="flex flex-wrap gap-2 mb-4">
                      {Array.from(new Set(seller.products.flatMap(p => p.tags))).slice(0, 3).map(tag => (
                        <span key={tag} className="px-2 py-1 rounded-md bg-gray-100 text-gray-800 text-sm">
                          {tag}
                        </span>
                      ))}
                    </div>
                    <button
                      className="w-full px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 flex items-center justify-center"
                      onClick={() => setSelectedSeller(seller)}
                    >
                      <User className="h-4 w-4 mr-2" />
                      View Products
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// Product Card Component
const ProductCard = ({ product, onSellerClick }: { product: Product, onSellerClick: (seller: Seller) => void }) => {
  return (
    <div className="border rounded-lg overflow-hidden hover:shadow-md transition-shadow">
      <div className="aspect-square bg-gray-100 relative overflow-hidden">
        <img 
          src={product.image} 
          alt={product.name}
          className="w-full h-full object-cover"
        />
      </div>
      <div className="p-6">
        <h3 className="text-xl font-semibold mb-2">{product.name}</h3>
        <p className="text-gray-600 mb-4">{product.description}</p>
        <div className="flex justify-between items-center mb-4">
          <span className="text-lg font-semibold">{formatCurrency(product.price)}</span>
          <span className="px-3 py-1 rounded-full bg-green-100 text-green-800 text-sm font-medium">
            +{product.impactValue} Impact
          </span>
        </div>
        <div className="flex items-center gap-2 text-sm text-gray-500 mb-4">
          <span>Sold by:</span>
          <button 
            onClick={() => {
              const fullSeller = mockSellers.find(seller => seller.id === product.seller.id)
              if (fullSeller) {
                onSellerClick(fullSeller)
              }
            }}
            className="font-medium hover:underline"
          >
            {product.seller.name}
          </button>
          <div className="flex items-center gap-1 ml-auto">
            <Star className="h-4 w-4 fill-yellow-400 text-yellow-400" />
            <span>{product.seller.rating}</span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2 mb-4">
          {product.tags.map(tag => (
            <span key={tag} className="px-2 py-1 rounded-md bg-gray-100 text-gray-800 text-sm">
              {tag}
            </span>
          ))}
        </div>
        <button
          className="w-full px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 flex items-center justify-center"
        >
          <ShoppingCart className="h-4 w-4 mr-2" />
          Add to Cart
        </button>
      </div>
    </div>
  )
}

export default MarketplaceGallery