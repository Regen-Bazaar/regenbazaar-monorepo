"use client";

import React, { useState } from "react";
import Navbar from "../components/navbar";
import NGODashboard from "../pages/NgoDashboard";
import CorporateDashboard from "../pages/CorporateDashboard";
import type { UserRole } from "../types/user";

export default function Home() {
  const [userRole, setUserRole] = useState<UserRole>("ngo");

  return (
    <div className="bg-secondary min-h-screen">
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 py-2">
        <select
          value={userRole}
          onChange={(e) => setUserRole(e.target.value as UserRole)}
          className="mb-4 px-4 py-2 border border-secondary-dark  bg-white text-accent focus:outline-none focus:ring-2 focus:ring-primary/20 rounded-full p-8 cursor-pointer"
        >
          <option value="ngo">NGO/Seller View</option>
          <option value="corporate">Corporate Buyer View</option>
        </select>
      </div>
      {userRole === "ngo" ? <NGODashboard /> : <CorporateDashboard />}
    </div>
  );
}
