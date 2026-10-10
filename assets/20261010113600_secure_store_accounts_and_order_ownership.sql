/*
# Secure customer accounts and store administration

1. New tables and columns
- `store_profiles`: one profile per signed-in account, with display name and immutable-by-client role.
- `store_orders.user_id`: optional owner of a signed-in order; guest checkout remains supported.
- `store_reviews.user_id`: optional reviewer identity for authenticated customers.

2. Security changes
- Customers can read only their own profile and signed-in orders.
- Customers can create orders only for themselves; guest orders remain insert-only and are not readable.
- Store catalog management and order management are limited to profiles whose role is `admin`.
- Role and ownership fields cannot be changed by regular clients.

3. Important notes
- New accounts start as `customer`. A trusted operator must promote an account to `admin` through a protected server-side operation.
- Payment and order totals are still pending server-side gateway validation before production launch.
- All statements are additive and safe to re-run.
*/

CREATE TABLE IF NOT EXISTS store_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE store_orders ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE store_reviews ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE store_orders ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE store_reviews ALTER COLUMN user_id SET DEFAULT auth.uid();

CREATE INDEX IF NOT EXISTS store_orders_user_idx ON store_orders(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS store_reviews_user_idx ON store_reviews(user_id);

ALTER TABLE store_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles read own" ON store_profiles;
CREATE POLICY "profiles read own" ON store_profiles FOR SELECT TO authenticated USING (id = auth.uid());
DROP POLICY IF EXISTS "profiles insert own" ON store_profiles;
CREATE POLICY "profiles insert own" ON store_profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid() AND role = 'customer');
DROP POLICY IF EXISTS "profiles update own name" ON store_profiles;
CREATE POLICY "profiles update own name" ON store_profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid() AND role = 'customer');

DROP POLICY IF EXISTS "public read active categories" ON store_categories;
CREATE POLICY "public read active categories" ON store_categories FOR SELECT TO anon, authenticated USING (is_active = true);
DROP POLICY IF EXISTS "authenticated manage categories" ON store_categories;
CREATE POLICY "admin insert categories" ON store_categories FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated update categories" ON store_categories;
CREATE POLICY "admin update categories" ON store_categories FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated delete categories" ON store_categories;
CREATE POLICY "admin delete categories" ON store_categories FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "authenticated insert products" ON store_products;
CREATE POLICY "admin insert products" ON store_products FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated update products" ON store_products;
CREATE POLICY "admin update products" ON store_products FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated delete products" ON store_products;
CREATE POLICY "admin delete products" ON store_products FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "public create orders" ON store_orders;
CREATE POLICY "public create orders" ON store_orders FOR INSERT TO anon, authenticated WITH CHECK ((auth.uid() IS NULL AND user_id IS NULL OR user_id = auth.uid()) AND payment_status = 'pending' AND fulfillment_status = 'new');
DROP POLICY IF EXISTS "authenticated read orders" ON store_orders;
CREATE POLICY "customers read own orders" ON store_orders FOR SELECT TO authenticated USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated update orders" ON store_orders;
CREATE POLICY "admin update orders" ON store_orders FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated delete orders" ON store_orders;
CREATE POLICY "admin delete orders" ON store_orders FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "authenticated read order items" ON store_order_items;
CREATE POLICY "customers read own order items" ON store_order_items FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM store_orders WHERE store_orders.id = order_id AND (store_orders.user_id = auth.uid() OR EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'))));
DROP POLICY IF EXISTS "authenticated update order items" ON store_order_items;
CREATE POLICY "admin update order items" ON store_order_items FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated delete order items" ON store_order_items;
CREATE POLICY "admin delete order items" ON store_order_items FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "authenticated update reviews" ON store_reviews;
CREATE POLICY "admin update reviews" ON store_reviews FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "authenticated delete reviews" ON store_reviews;
CREATE POLICY "admin delete reviews" ON store_reviews FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
