import { create } from "zustand";
import { getCurrentUser, getUserProfile, supabase } from "~~/utils/supabase/supabaseClient";

interface UserProfile {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string;
  bio: string;
  rwi_rank: number;
  rebaz_balance: number;
  created_at: string;
}

interface AuthState {
  user: any | null;
  profile: UserProfile | null;
  isLoading: boolean;
  error: string | null;
  initialize: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, username: string) => Promise<void>;
  loginWithProvider: (provider: "google" | "facebook" | "twitter") => Promise<void>;
  logout: () => Promise<void>;
  updateProfile: (updates: Partial<UserProfile>) => Promise<void>;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  profile: null,
  isLoading: true,
  error: null,

  initialize: async () => {
    try {
      set({ isLoading: true });
      const user = await getCurrentUser();

      if (user) {
        const profile = await getUserProfile(user.id);
        set({ user, profile, isLoading: false });
      } else {
        set({ user: null, profile: null, isLoading: false });
      }
    } catch (error) {
      console.error("Auth initialization error:", error);
      set({ user: null, profile: null, isLoading: false, error: "Failed to initialize auth" });
    }
  },

  login: async (email, password) => {
    try {
      set({ isLoading: true, error: null });
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });

      if (error) throw error;

      if (data.user) {
        const profile = await getUserProfile(data.user.id);
        set({ user: data.user, profile, isLoading: false });
      }
    } catch (error: any) {
      console.error("Login error:", error);
      set({ isLoading: false, error: error.message || "Failed to login" });
    }
  },

  register: async (email, password, username) => {
    try {
      set({ isLoading: true, error: null });

      const { data, error } = await supabase.auth.signUp({ email, password });

      if (error) throw error;

      if (data.user) {
        const { error: profileError } = await supabase.from("profiles").insert([
          {
            id: data.user.id,
            username,
            full_name: "",
            avatar_url: "",
            bio: "",
            rwi_rank: 0,
            rebaz_balance: 0,
          },
        ]);

        if (profileError) throw profileError;

        const profile = await getUserProfile(data.user.id);
        set({ user: data.user, profile, isLoading: false });
      }
    } catch (error: any) {
      console.error("Registration error:", error);
      set({ isLoading: false, error: error.message || "Failed to register" });
    }
  },

  loginWithProvider: async provider => {
    try {
      set({ isLoading: true, error: null });
      const { error } = await supabase.auth.signInWithOAuth({ provider });

      if (error) throw error;

      // Note: I don't set the user here because the OAuth flow will redirect the user
      // The user will be set when the app initializes after the redirect
    } catch (error: any) {
      console.error("OAuth login error:", error);
      set({ isLoading: false, error: error.message || `Failed to login with ${provider}` });
    }
  },

  logout: async () => {
    try {
      set({ isLoading: true });
      await supabase.auth.signOut();
      set({ user: null, profile: null, isLoading: false });
    } catch (error: any) {
      console.error("Logout error:", error);
      set({ isLoading: false, error: error.message || "Failed to logout" });
    }
  },

  updateProfile: async updates => {
    try {
      const { user, profile } = get();

      if (!user || !profile) {
        throw new Error("User not authenticated");
      }

      set({ isLoading: true });

      const { error } = await supabase.from("profiles").update(updates).eq("id", user.id);

      if (error) throw error;

      const updatedProfile = await getUserProfile(user.id);
      set({ profile: updatedProfile, isLoading: false });
    } catch (error: any) {
      console.error("Profile update error:", error);
      set({ isLoading: false, error: error.message || "Failed to update profile" });
    }
  },
}));
