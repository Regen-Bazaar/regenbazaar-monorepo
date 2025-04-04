export type UserRole = "ngo" | "corporate";

export interface User {
  id: string;
  name: string;
  role: UserRole;
  email: string;
}

export interface Order {
  id: string;
  orderNumber: string;
  buyerName: string;
  status: "pending" | "completed" | "in_progress";
  amount: number;
  createdAt: string;
}

export interface Product {
  id: string;
  name: string;
  stock: number;
  price: number;
  status: "in_stock" | "low_stock" | "out_of_stock";
}
