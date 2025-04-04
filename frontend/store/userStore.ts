import { create } from "zustand";
import type { User, Order, Product } from "../types/user";

interface Store {
  user: User | null;
  orders: Order[];
  products: Product[];
  activeOrders: number;
  totalRevenue: number;
  setUser: (user: User | null) => void;
  addOrder: (order: Order) => void;
  updateOrderStatus: (orderId: string, status: Order["status"]) => void;
  addProduct: (product: Product) => void;
  updateProductStock: (productId: string, stock: number) => void;
}

export const useStore = create<Store>((set) => ({
  user: null,
  orders: [
    {
      id: "1",
      orderNumber: "#1234",
      buyerName: "Corporate Buyer 1",
      status: "completed",
      amount: 500,
      createdAt: new Date().toISOString(),
    },
    {
      id: "2",
      orderNumber: "#1235",
      buyerName: "Corporate Buyer 2",
      status: "pending",
      amount: 750,
      createdAt: new Date().toISOString(),
    },
    {
      id: "3",
      orderNumber: "#1236",
      buyerName: "Corporate Buyer 3",
      status: "in_progress",
      amount: 1200,
      createdAt: new Date().toISOString(),
    },
  ],
  products: [
    {
      id: "1",
      name: "Sustainable Product 1",
      stock: 50,
      price: 99.99,
      status: "in_stock",
    },
    {
      id: "2",
      name: "Sustainable Product 2",
      stock: 10,
      price: 149.99,
      status: "low_stock",
    },
    {
      id: "3",
      name: "Sustainable Product 3",
      stock: 0,
      price: 199.99,
      status: "out_of_stock",
    },
  ],
  activeOrders: 5,
  totalRevenue: 2450,

  setUser: (user) => set({ user }),

  addOrder: (order) =>
    set((state) => ({
      orders: [...state.orders, order],
      activeOrders: state.activeOrders + 1,
      totalRevenue: state.totalRevenue + order.amount,
    })),

  updateOrderStatus: (orderId, status) =>
    set((state) => ({
      orders: state.orders.map((order) =>
        order.id === orderId ? { ...order, status } : order
      ),
    })),

  addProduct: (product) =>
    set((state) => ({
      products: [...state.products, product],
    })),

  updateProductStock: (productId, stock) =>
    set((state) => ({
      products: state.products.map((product) =>
        product.id === productId
          ? {
              ...product,
              stock,
              status:
                stock > 10
                  ? "in_stock"
                  : stock > 0
                  ? "low_stock"
                  : "out_of_stock",
            }
          : product
      ),
    })),
}));
