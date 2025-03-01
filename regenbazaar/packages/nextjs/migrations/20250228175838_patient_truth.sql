/*
  # Schema

  1. New Tables
    - `profiles`
      - `id` (uuid, primary key)
      - `username` (text, unique)
      - `full_name` (text)
      - `avatar_url` (text)
      - `bio` (text)
      - `rwi_rank` (integer)
      - `rebaz_balance` (integer)
      - `created_at` (timestamptz)
    - `follows`
      - `id` (uuid, primary key)
      - `follower_id` (uuid, references profiles.id)
      - `creator_id` (uuid, references profiles.id)
      - `created_at` (timestamptz)
    - `impact_products`
      - `id` (uuid, primary key)
      - `creator_id` (uuid, references profiles.id)
      - `organization_type` (text)
      - `entity_name` (text)
      - `actions` (jsonb)
      - `proof_link` (text)
      - `technical_level` (text)
      - `price` (numeric)
      - `impact_value` (integer)
      - `status` (text)
      - `created_at` (timestamptz)
  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  full_name text,
  avatar_url text,
  bio text,
  rwi_rank integer DEFAULT 0,
  rebaz_balance integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create follows table
CREATE TABLE IF NOT EXISTS follows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  creator_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(follower_id, creator_id)
);

-- Create impact_products table
CREATE TABLE IF NOT EXISTS impact_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  organization_type text NOT NULL,
  entity_name text NOT NULL,
  actions jsonb NOT NULL,
  proof_link text NOT NULL,
  technical_level text NOT NULL,
  price numeric NOT NULL,
  impact_value integer NOT NULL,
  status text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE impact_products ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles
  FOR SELECT
  USING (true);

CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- Follows policies
CREATE POLICY "Follows are viewable by everyone"
  ON follows
  FOR SELECT
  USING (true);

CREATE POLICY "Users can follow creators"
  ON follows
  FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow creators"
  ON follows
  FOR DELETE
  USING (auth.uid() = follower_id);

-- Impact products policies
CREATE POLICY "Impact products are viewable by everyone"
  ON impact_products
  FOR SELECT
  USING (true);

CREATE POLICY "Users can create their own impact products"
  ON impact_products
  FOR INSERT
  WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can update their own impact products"
  ON impact_products
  FOR UPDATE
  USING (auth.uid() = creator_id);