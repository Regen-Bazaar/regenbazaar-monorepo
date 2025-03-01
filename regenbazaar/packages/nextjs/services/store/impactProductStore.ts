import { create } from "zustand";
import {
  createImpactProduct,
  getCreatorProducts,
  getImpactProductById,
  getImpactProducts,
} from "~~/utils/supabase/supabaseClient";

interface ImpactProductState {
  products: any[];
  currentProduct: any | null;
  creatorProducts: any[];
  isLoading: boolean;
  error: string | null;
  currentStep: number;
  formData: any;
  fetchProducts: () => Promise<void>;
  fetchProductById: (id: string) => Promise<void>;
  fetchCreatorProducts: (creatorId: string) => Promise<void>;
  createProduct: (productData: any) => Promise<any>;
  setCurrentStep: (step: number) => void;
  updateFormData: (data: any) => void;
  resetForm: () => void;
}

const initialFormData = {
  organizationType: "",
  entityName: "",
  actions: [
    {
      title: "",
      achievedImpact: "",
      period: "",
      location: "",
    },
  ],
  proofLink: "",
  technicalLevel: "Low",
  price: "",
  impactValue: 0,
};

export const useImpactProductStore = create<ImpactProductState>((set, get) => ({
  products: [],
  currentProduct: null,
  creatorProducts: [],
  isLoading: false,
  error: null,
  currentStep: 1,
  formData: { ...initialFormData },

  fetchProducts: async () => {
    try {
      set({ isLoading: true });
      const products = await getImpactProducts();
      set({ products, isLoading: false });
    } catch (error: any) {
      console.error("Error fetching products:", error);
      set({ isLoading: false, error: error.message || "Failed to fetch products" });
    }
  },

  fetchProductById: async id => {
    try {
      set({ isLoading: true });
      const product = await getImpactProductById(id);
      set({ currentProduct: product, isLoading: false });
    } catch (error: any) {
      console.error("Error fetching product:", error);
      set({ isLoading: false, error: error.message || "Failed to fetch product" });
    }
  },

  fetchCreatorProducts: async creatorId => {
    try {
      set({ isLoading: true });
      const products = await getCreatorProducts(creatorId);
      set({ creatorProducts: products, isLoading: false });
    } catch (error: any) {
      console.error("Error fetching creator products:", error);
      set({ isLoading: false, error: error.message || "Failed to fetch creator products" });
    }
  },

  createProduct: async productData => {
    try {
      set({ isLoading: true });
      const newProduct = await createImpactProduct(productData);

      // Update the products list
      const { products } = get();
      set({
        products: [...products, newProduct],
        isLoading: false,
        currentStep: 1,
        formData: { ...initialFormData },
      });

      return newProduct;
    } catch (error: any) {
      console.error("Error creating product:", error);
      set({ isLoading: false, error: error.message || "Failed to create product" });
      throw error;
    }
  },

  setCurrentStep: step => {
    set({ currentStep: step });
  },

  updateFormData: data => {
    set({ formData: { ...get().formData, ...data } });
  },

  resetForm: () => {
    set({ currentStep: 1, formData: { ...initialFormData } });
  },
}));
