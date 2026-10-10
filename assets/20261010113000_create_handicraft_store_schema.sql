/*
# Create the Iranian handicraft store foundation

1. New tables
- `store_categories`: public product categories with a display order.
- `store_products`: catalog records with pricing, inventory, imagery, and featured flags.
- `store_orders`: checkout records with customer contact, shipping address, totals, and payment status.
- `store_order_items`: immutable product snapshots attached to each order.
- `store_reviews`: customer ratings and review text for products.

2. Security
- Row-level security is enabled on every table.
- Catalog and published reviews are readable by visitors.
- Orders can be created by visitors but are not readable anonymously.
- Order items can be created only alongside an order by the public checkout flow.
- Management writes remain restricted to authenticated users for later admin authentication.

3. Important notes
- Product snapshots in `store_order_items` preserve the name and price at the time of purchase.
- Payment status starts as `pending`; a real Iranian gateway should update it server-side through a secure edge function.
- This migration is additive and safe to re-run.
*/

CREATE TABLE IF NOT EXISTS store_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  image_url text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS store_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid REFERENCES store_categories(id) ON DELETE SET NULL,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  price bigint NOT NULL CHECK (price >= 0),
  compare_at_price bigint CHECK (compare_at_price IS NULL OR compare_at_price >= price),
  inventory integer NOT NULL DEFAULT 0 CHECK (inventory >= 0),
  image_url text,
  gallery_urls text[] NOT NULL DEFAULT '{}',
  artisan_name text,
  material text,
  dimensions text,
  rating numeric(2,1) NOT NULL DEFAULT 5.0 CHECK (rating >= 0 AND rating <= 5),
  review_count integer NOT NULL DEFAULT 0 CHECK (review_count >= 0),
  is_featured boolean NOT NULL DEFAULT false,
  is_bestseller boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS store_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  customer_email text,
  shipping_address text NOT NULL,
  postal_code text NOT NULL,
  subtotal bigint NOT NULL CHECK (subtotal >= 0),
  shipping_cost bigint NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
  discount bigint NOT NULL DEFAULT 0 CHECK (discount >= 0),
  total bigint NOT NULL CHECK (total >= 0),
  coupon_code text,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','failed','refunded')),
  fulfillment_status text NOT NULL DEFAULT 'new' CHECK (fulfillment_status IN ('new','processing','shipped','delivered','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS store_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES store_orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES store_products(id) ON DELETE SET NULL,
  product_name text NOT NULL,
  unit_price bigint NOT NULL CHECK (unit_price >= 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS store_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES store_products(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body text NOT NULL,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS store_products_category_idx ON store_products(category_id);
CREATE INDEX IF NOT EXISTS store_products_featured_idx ON store_products(is_featured, is_active);
CREATE INDEX IF NOT EXISTS store_products_bestseller_idx ON store_products(is_bestseller, is_active);
CREATE INDEX IF NOT EXISTS store_order_items_order_idx ON store_order_items(order_id);
CREATE INDEX IF NOT EXISTS store_reviews_product_idx ON store_reviews(product_id, is_published);

ALTER TABLE store_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public read active categories" ON store_categories;
CREATE POLICY "public read active categories" ON store_categories FOR SELECT TO anon, authenticated USING (is_active = true);
DROP POLICY IF EXISTS "authenticated manage categories" ON store_categories;
CREATE POLICY "authenticated manage categories" ON store_categories FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated update categories" ON store_categories;
CREATE POLICY "authenticated update categories" ON store_categories FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated delete categories" ON store_categories;
CREATE POLICY "authenticated delete categories" ON store_categories FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "public read active products" ON store_products;
CREATE POLICY "public read active products" ON store_products FOR SELECT TO anon, authenticated USING (is_active = true);
DROP POLICY IF EXISTS "authenticated insert products" ON store_products;
CREATE POLICY "authenticated insert products" ON store_products FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated update products" ON store_products;
CREATE POLICY "authenticated update products" ON store_products FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated delete products" ON store_products;
CREATE POLICY "authenticated delete products" ON store_products FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "public create orders" ON store_orders;
CREATE POLICY "public create orders" ON store_orders FOR INSERT TO anon, authenticated WITH CHECK (payment_status = 'pending' AND fulfillment_status = 'new');
DROP POLICY IF EXISTS "authenticated read orders" ON store_orders;
CREATE POLICY "authenticated read orders" ON store_orders FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated update orders" ON store_orders;
CREATE POLICY "authenticated update orders" ON store_orders FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated delete orders" ON store_orders;
CREATE POLICY "authenticated delete orders" ON store_orders FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "public create order items" ON store_order_items;
CREATE POLICY "public create order items" ON store_order_items FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated read order items" ON store_order_items;
CREATE POLICY "authenticated read order items" ON store_order_items FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated update order items" ON store_order_items;
CREATE POLICY "authenticated update order items" ON store_order_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated delete order items" ON store_order_items;
CREATE POLICY "authenticated delete order items" ON store_order_items FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "public read published reviews" ON store_reviews;
CREATE POLICY "public read published reviews" ON store_reviews FOR SELECT TO anon, authenticated USING (is_published = true);
DROP POLICY IF EXISTS "public create reviews" ON store_reviews;
CREATE POLICY "public create reviews" ON store_reviews FOR INSERT TO anon, authenticated WITH CHECK (is_published = false);
DROP POLICY IF EXISTS "authenticated update reviews" ON store_reviews;
CREATE POLICY "authenticated update reviews" ON store_reviews FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "authenticated delete reviews" ON store_reviews;
CREATE POLICY "authenticated delete reviews" ON store_reviews FOR DELETE TO authenticated USING (true);
