import { createClient } from "@supabase/supabase-js";

// Initialize Supabase client
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL! || "";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY! || "";

if (!supabaseUrl || !supabaseAnonKey) {
  console.error("Missing Supabase environment variables");
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Auth functions
export const signInWithEmail = async (email: string, password: string) => {
  return await supabase.auth.signInWithPassword({ email, password });
};

export const signUpWithEmail = async (email: string, password: string) => {
  return await supabase.auth.signUp({ email, password });
};

export const signInWithProvider = async (provider: "google" | "facebook" | "twitter") => {
  return await supabase.auth.signInWithOAuth({ provider });
};

export const signOut = async () => {
  return await supabase.auth.signOut();
};

export const getCurrentUser = async () => {
  const { data } = await supabase.auth.getUser();
  return data.user;
};

// User profile functions
export const getUserProfile = async (userId: string) => {
  const { data, error } = await supabase.from("profiles").select("*").eq("id", userId).single();

  if (error) throw error;
  return data;
};

export const updateUserProfile = async (userId: string, updates: any) => {
  const { data, error } = await supabase.from("profiles").update(updates).eq("id", userId);

  if (error) throw error;
  return data;
};

// Follow functions
export const followCreator = async (followerId: string, creatorId: string) => {
  const { data, error } = await supabase.from("follows").insert([{ follower_id: followerId, creator_id: creatorId }]);

  if (error) throw error;
  return data;
};

export const unfollowCreator = async (followerId: string, creatorId: string) => {
  const { data, error } = await supabase
    .from("follows")
    .delete()
    .match({ follower_id: followerId, creator_id: creatorId });

  if (error) throw error;
  return data;
};

export const getFollowers = async (creatorId: string) => {
  const { data, error } = await supabase.from("follows").select("follower_id, profiles(*)").eq("creator_id", creatorId);

  if (error) throw error;
  return data;
};

export const getFollowing = async (followerId: string) => {
  const { data, error } = await supabase
    .from("follows")
    .select("creator_id, profiles(*)")
    .eq("follower_id", followerId);

  if (error) throw error;
  return data;
};

// Impact product functions
export const createImpactProduct = async (productData: any) => {
  const { data, error } = await supabase.from("impact_products").insert([productData]);

  if (error) throw error;
  return data;
};

export const getImpactProducts = async () => {
  const { data, error } = await supabase.from("impact_products").select("*, profiles(*)");

  if (error) throw error;
  return data;
};

export const getImpactProductById = async (id: string) => {
  const { data, error } = await supabase.from("impact_products").select("*, profiles(*)").eq("id", id).single();

  if (error) throw error;
  return data;
};

export const getCreatorProducts = async (creatorId: string) => {
  const { data, error } = await supabase.from("impact_products").select("*").eq("creator_id", creatorId);

  if (error) throw error;
  return data;
};
