/*
# Expand admin read access for management screens

1. Security changes
- Existing admins can read inactive categories and products so hidden catalog items can be managed.
- Existing admins can read unpublished reviews so moderation is possible.

2. Important notes
- Public visitors still receive only active products/categories and published reviews.
- No write access is granted beyond the existing admin-only policies.
- This migration is additive and safe to re-run.
*/

DROP POLICY IF EXISTS "admin read all categories" ON store_categories;
CREATE POLICY "admin read all categories" ON store_categories FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "admin read all products" ON store_products;
CREATE POLICY "admin read all products" ON store_products FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "admin read all reviews" ON store_reviews;
CREATE POLICY "admin read all reviews" ON store_reviews FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
