import React from "react";
import { ShoppingCart, Heart, Clock, Receipt, Plus } from "lucide-react";
import { useStore } from "@/store/userStore";
import { format } from "date-fns";

export default function CorporateDashboard() {
  const { orders, products, addOrder } = useStore();

  const handleCreateOrder = (productId: string) => {
    const newOrder = {
      id: (orders.length + 1).toString(),
      orderNumber: `#${Math.floor(1000 + Math.random() * 9000)}`,
      buyerName: "Corporate Buyer",
      status: "pending" as const,
      amount: products.find((p) => p.id === productId)?.price || 0,
      createdAt: new Date().toISOString(),
    };
    addOrder(newOrder);
  };

  const pendingOrders = orders.filter(
    (order) => order.status === "pending"
  ).length;
  const completedOrders = orders.filter(
    (order) => order.status === "completed"
  ).length;
  const wishlistCount = 15; // Mock data

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <h1 className="text-2xl font-bold mb-6 text-accent">
        Corporate Buyer Dashboard
      </h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <ShoppingCart className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Orders</p>
              <p className="text-2xl font-semibold text-accent">
                {orders.length}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <Heart className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Wishlist</p>
              <p className="text-2xl font-semibold text-accent">
                {wishlistCount}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <Clock className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Pending</p>
              <p className="text-2xl font-semibold text-accent">
                {pendingOrders}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <Receipt className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Completed</p>
              <p className="text-2xl font-semibold text-accent">
                {completedOrders}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark h-[500px] flex flex-col">
          <h2 className="text-lg font-semibold mb-4 text-accent">
            Recent Orders
          </h2>
          <div className="space-y-4 overflow-y-auto flex-1">
            {orders.map((order) => (
              <div
                key={order.id}
                className="flex items-center justify-between py-2 border-b border-secondary-dark"
              >
                <div>
                  <p className="font-medium text-accent">{order.orderNumber}</p>
                  <p className="text-sm text-accent-light">
                    Amount: ${order.amount}
                  </p>
                  <p className="text-xs text-accent-light">
                    {format(new Date(order.createdAt), "MMM dd, yyyy")}
                  </p>
                </div>
                <span
                  className={`px-3 py-1 text-sm rounded-full ${
                    order.status === "completed"
                      ? "bg-green-100 text-green-800"
                      : order.status === "pending"
                      ? "bg-yellow-100 text-yellow-800"
                      : "bg-blue-100 text-blue-800"
                  }`}
                >
                  {order.status.charAt(0).toUpperCase() +
                    order.status.slice(1).replace("_", " ")}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark h-[500px] flex flex-col">
          <h2 className="text-lg font-semibold mb-4 text-accent">
            Available Products
          </h2>
          <div className="space-y-4 overflow-y-auto flex-1">
            {products.map((product) => (
              <div
                key={product.id}
                className="flex items-center justify-between py-2 border-b border-secondary-dark"
              >
                <div>
                  <p className="font-medium text-accent">{product.name}</p>
                  <p className="text-sm text-accent-light">${product.price}</p>
                  <p className="text-xs text-accent-light">
                    Stock: {product.stock}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleCreateOrder(product.id)}
                    disabled={product.stock === 0}
                    className={`flex items-center gap-1 px-3 py-1 text-sm rounded-full cursor-pointer ${
                      product.stock === 0
                        ? "bg-gray-100 text-gray-400 cursor-not-allowed"
                        : "bg-primary text-white hover:bg-primary-dark"
                    }`}
                  >
                    <Plus size={14} />
                    Order
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
