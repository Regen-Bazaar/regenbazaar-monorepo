import React from "react";
import { Package2, Users, Calendar, BarChart3, Plus } from "lucide-react";
import { useStore } from "@/store/userStore";
import { format } from "date-fns";
import { Product } from "@/types/user";
export default function NGODashboard() {
  const {
    orders,
    products,
    activeOrders,
    totalRevenue,
    addProduct,
    updateProductStock,
  } = useStore();

  const handleAddProduct = () => {
    const newProduct: Product = {
      id: (products.length + 1).toString(),
      name: `New Product ${products.length + 1}`,
      stock: 100,
      price: 99.99,
      status: "in_stock",
    };
    addProduct(newProduct);
  };

  const handleUpdateStock = (productId: string, currentStock: number) => {
    const newStock = currentStock + 10;
    updateProductStock(productId, newStock);
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-accent">NGO/Seller Dashboard</h1>
        <button
          onClick={handleAddProduct}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-full 
             hover:bg-accent hover:text-secondary cursor-pointer transition-all duration-300"
        >
          <Plus size={18} />
          Add Product
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <Package2 className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Total Products</p>
              <p className="text-2xl font-semibold text-accent">
                {products.length}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <Users className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Active Buyers</p>
              <p className="text-2xl font-semibold text-accent">12</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <Calendar className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Pending Orders</p>
              <p className="text-2xl font-semibold text-accent">
                {activeOrders}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark">
          <div className="flex items-center gap-4">
            <BarChart3 className="w-8 h-8 text-primary" />
            <div>
              <p className="text-accent-light">Total Revenue</p>
              <p className="text-2xl font-semibold text-accent">
                ${totalRevenue.toLocaleString()}
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
                  <p className="text-sm text-accent-light">{order.buyerName}</p>
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
                  {order.status.charAt(0).toUpperCase() + order.status.slice(1)}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-secondary-dark h-[500px] flex flex-col">
          <h2 className="text-lg font-semibold mb-4 text-accent">
            Product Inventory
          </h2>
          <div className="space-y-4 overflow-y-auto flex-1">
            {products.map((product) => (
              <div
                key={product.id}
                className="flex items-center justify-between py-2 border-b border-secondary-dark"
              >
                <div>
                  <p className="font-medium text-accent">{product.name}</p>
                  <p className="text-sm text-accent-light">
                    Stock: {product.stock}
                  </p>
                  <p className="text-sm text-accent-light">${product.price}</p>
                </div>
                <div className="flex items-center gap-2">
                  <span
                    className={`px-3 py-1 text-sm rounded-full ${
                      product.status === "in_stock"
                        ? "bg-green-100 text-green-800"
                        : product.status === "low_stock"
                        ? "bg-yellow-100 text-yellow-800"
                        : "bg-red-100 text-red-800"
                    }`}
                  >
                    {/* Fixed: Handle the status display correctly */}
                    {product.status === "in_stock"
                      ? "In Stock"
                      : product.status === "low_stock"
                      ? "Low Stock"
                      : "Out of Stock"}
                  </span>
                  <button
                    onClick={() => handleUpdateStock(product.id, product.stock)}
                    className="px-3 py-1 text-sm bg-primary/10 text-primary rounded-full hover:bg-primary/20 cursor-pointer"
                  >
                    Add Stock
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
