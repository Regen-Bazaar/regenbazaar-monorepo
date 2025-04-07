/* eslint-disable @next/next/no-img-element */
'use client'
import { useState } from 'react';
import Head from 'next/head';

// Component for the user header with avatar and basic info
const UserHeader = ({ username, rawRank, vxREBA2 }: { username: string; rawRank: number; vxREBA2: number }) => {
  return (
    <div className="flex items-center">
      <div className="w-10 h-10 rounded-full bg-blue-400 overflow-hidden mr-3">
        <img
          src={`https://ui-avatars.com/api/?name=${username.replace(' ', '+')}&background=4299E1&color=fff`}
          alt={username}
          className="w-full h-full object-cover"
        />
      </div>
      <div className='flex items-center gap-14'>
        <span className="text-xl font-medium">{username}</span>
        <div className="flex text-md text-gray-400 ">
          <span className="mr-4">RAW RANK: <span className='text-[#acf388]'> {rawRank}</span></span>
          <span>vxREBA2: <span className='text-[#acf388]'> {vxREBA2}</span></span>
        </div>
      </div>
    </div>
  );
};

// Component for the navigation buttons
const NavigationButtons = () => {
  return (
    <div className="flex">
      <button className="bg-[#acf388] text-gray-700 text-sm px-3 py-1 rounded-md mr-2">Dashboard</button>
      <button className="text-sm px-3 py-1 text-gray-400">Purchase</button>
      <button className="text-sm px-3 py-1 text-gray-400">Stake</button>
      <button className="text-sm px-3 py-1 text-gray-400">Vote</button>
      <button className="text-gray-400 ml-4">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
        </svg>
      </button>
    </div>
  );
};

// Component for displaying a single stat item
const StatItem = ({ label, value, colorClass = "text-[#acf388]" }: { label: string; value: string | number; colorClass?: string }) => {
  return (
    <>
      <div className="text-gray-400">{label}:</div>
      <div className={`text-right ${colorClass}`}>{value}</div>
    </>
  );
};

// Interface for the stats object
interface Stats {
  rawRank: number;
  votingPower: number;
  stakedIp: number;
  apyForStakedIp: string;
  stakedTokens: number;
  apyForStakedTokens: string;
}

// Component for the user stats panel
const StatsPanel = ({ stats }: { stats: Stats }) => {
  return (
    <div className="rounded-md flex flex-col gap-1">
      <h2 className="text-xl font-bold mb-3 text-gray-200 bg-[#1f2937] rounded-md p-4">STATS</h2>
      <div className="grid grid-cols-2 gap-2 text-sm bg-[#0a0f19] rounded-md p-4">
        <StatItem label="RAW RANK" value={stats.rawRank} />
        <StatItem label="VOTING POWER, vxREBA2" value={stats.votingPower} />
        <StatItem label="STAKED IP" value={stats.stakedIp} />
        <StatItem label="APY FOR STAKED IP" value={stats.apyForStakedIp} />
        <StatItem label="STAKED TOKENS" value={stats.stakedTokens} />
        <StatItem label="APY FOR STAKED TOKENS" value={stats.apyForStakedTokens} />
      </div>
    </div>
  );
};

// Interface for the product object
interface Product {
  id: number;
  title: string;
  image: string;
  type: string;
  price: string;
  roi: string;
  unit: string;
}

// Component for a single product card
const ProductCard = ({ product }: { product: Product }) => {
  return (
    <div className="rounded-md overflow-hidden bg-gray-800">
      <div className="h-32 bg-gray-700 relative">
        <img
          src={product.image}
          alt={product.title}
          className="w-full h-full object-cover"
        />
      </div>
      <div className="p-2 space-y-3">
        <h3 className="text-sm font-medium">{product.title}</h3>
        <div className="flex justify-between text-xs mt-1">
          <span className="text-gray-400">{product.type}</span>
          <span className="text-gray-400">staked value</span>
        </div>
        <div className="flex justify-between text-xs mt-1">
          <span className="text-[#acf388]">{product.unit} {product.price}</span>
          <span>{product.roi}</span>
        </div>
      </div>
    </div>
  );
};

// Component for the add product button
const AddProductButton = () => {
  return (
    <div className="rounded-md overflow-hidden bg-gray-800 flex items-center justify-center h-full">
      <button className="text-4xl text-white">+</button>
    </div>
  );
};

// Component for the products grid
const ProductsGrid = ({ products, title }: { products: Product[]; title: string }) => {
  return (
    <div className="lg:col-span-3 flex flex-col gap-2 rounded-md">
      <h2 className="font-bold mb-3 text-gray-200 bg-[#1f2937] rounded-md p-4 text-xl">{title}</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4 bg-[#0a0f19] rounded-md p-4">
        {products.map(product => (
          <ProductCard key={product.id} product={product} />
        ))}
        <AddProductButton />
      </div>
    </div>
  );
};

// Main User Profile component
export default function UserProfile() {
  const [products] = useState([
    {
      id: 1,
      title: "Community gardens",
      image: "https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80",
      type: "Environmental",
      price: "0.005",
      roi: "0.1",
      unit: "ETH"
    },
    {
      id: 2,
      title: "Clean Phuripan",
      image: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80",
      type: "Environmental",
      price: "0.005",
      roi: "5",
      unit: "ETH"
    },
    {
      id: 3,
      title: "Decleanup",
      image: "https://images.unsplash.com/photo-1526400473556-aac12354f3db?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80",
      type: "Environmental",
      price: "0.02",
      roi: "10",
      unit: "ETH"
    }
  ]);

  const userStats = {
    rawRank: 70,
    votingPower: 170,
    stakedIp: 5,
    apyForStakedIp: "20%",
    stakedTokens: 20000,
    apyForStakedTokens: "9%"
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <Head>
        <title>User Profile | Impact Platform</title>
        <meta name="description" content="User profile on the impact platform" />
      </Head>

      <div className="container mx-auto px-4">
        {/* Header */}
        <header className="py-4 flex items-center justify-between">
          <UserHeader username="Paul Burg" rawRank={userStats.rawRank} vxREBA2={150} />
          <NavigationButtons />
        </header>

        {/* Main Content */}
        <main className="py-6">
          <h1 className="text-4xl font-bold text-[#acf388] mb-6">USER PROFILE</h1>

          <div className="grid grid-cols-1 lg:grid-cols-4 gap-4 mb-8">
            {/* Stats Panel */}
            <StatsPanel stats={userStats} />

            {/* Purchased Products */}
            <ProductsGrid 
              products={products} 
              title="PURCHASED IMPACT PRODUCTS" 
            />
          </div>
        </main>
      </div>
    </div>
  );
}