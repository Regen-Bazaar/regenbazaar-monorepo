import { create } from "zustand";
import { followCreator, getFollowers, getFollowing, unfollowCreator } from "~~/utils/supabase/supabaseClient";

interface FollowState {
  followers: any[];
  following: any[];
  isLoading: boolean;
  error: string | null;
  fetchFollowers: (creatorId: string) => Promise<void>;
  fetchFollowing: (userId: string) => Promise<void>;
  follow: (followerId: string, creatorId: string) => Promise<void>;
  unfollow: (followerId: string, creatorId: string) => Promise<void>;
  isFollowing: (followerId: string, creatorId: string) => boolean;
}

export const useFollowStore = create<FollowState>((set, get) => ({
  followers: [],
  following: [],
  isLoading: false,
  error: null,

  fetchFollowers: async creatorId => {
    try {
      set({ isLoading: true });
      const followers = await getFollowers(creatorId);
      set({ followers, isLoading: false });
    } catch (error: any) {
      console.error("Error fetching followers:", error);
      set({ isLoading: false, error: error.message || "Failed to fetch followers" });
    }
  },

  fetchFollowing: async userId => {
    try {
      set({ isLoading: true });
      const following = await getFollowing(userId);
      set({ following, isLoading: false });
    } catch (error: any) {
      console.error("Error fetching following:", error);
      set({ isLoading: false, error: error.message || "Failed to fetch following" });
    }
  },

  follow: async (followerId, creatorId) => {
    try {
      set({ isLoading: true });
      await followCreator(followerId, creatorId);

      // Update the following list
      const { following } = get();
      const updatedFollowing = [...following, { creator_id: creatorId }];
      set({ following: updatedFollowing, isLoading: false });
    } catch (error: any) {
      console.error("Error following creator:", error);
      set({ isLoading: false, error: error.message || "Failed to follow creator" });
    }
  },

  unfollow: async (followerId, creatorId) => {
    try {
      set({ isLoading: true });
      await unfollowCreator(followerId, creatorId);

      // Update the following list
      const { following } = get();
      const updatedFollowing = following.filter(f => f.creator_id !== creatorId);
      set({ following: updatedFollowing, isLoading: false });
    } catch (error: any) {
      console.error("Error unfollowing creator:", error);
      set({ isLoading: false, error: error.message || "Failed to unfollow creator" });
    }
  },

  isFollowing: (followerId, creatorId) => {
    const { following } = get();
    return following.some(f => f.creator_id === creatorId);
  },
}));
