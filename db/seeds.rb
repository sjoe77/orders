# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Clear existing data in development
if Rails.env.development?
  puts "Clearing existing data..."
  OrderLineItem.destroy_all
  Order.destroy_all
  InventoryItem.destroy_all
  ProductTag.destroy_all
  ProductCategory.destroy_all
  Address.destroy_all
  Customer.destroy_all
  Product.destroy_all
  Tag.destroy_all
  Category.destroy_all
end

puts "Creating sample data for testing..."

# Create Categories
categories = [
  { name_nm: "Athletic Shoes", description_txt: "Running, training, and sports footwear", display_order_num: 1 },
  { name_nm: "Casual Shoes", description_txt: "Everyday wear and lifestyle footwear", display_order_num: 2 },
  { name_nm: "Dress Shoes", description_txt: "Formal and business footwear", display_order_num: 3 },
  { name_nm: "Boots", description_txt: "Work boots, hiking boots, and fashion boots", display_order_num: 4 },
  { name_nm: "Sandals", description_txt: "Summer and casual open footwear", display_order_num: 5 }
]

categories.each do |category_attrs|
  Category.find_or_create_by!(name_nm: category_attrs[:name_nm]) do |category|
    category.assign_attributes(category_attrs)
  end
end

puts "Created #{Category.count} categories"

# Create Tags
tags = [
  { name_nm: "waterproof", color_code_nm: "#2196F3" },
  { name_nm: "lightweight", color_code_nm: "#4CAF50" },
  { name_nm: "leather", color_code_nm: "#795548" },
  { name_nm: "vegan", color_code_nm: "#8BC34A" },
  { name_nm: "breathable", color_code_nm: "#00BCD4" },
  { name_nm: "slip-resistant", color_code_nm: "#FF9800" },
  { name_nm: "memory-foam", color_code_nm: "#9C27B0" },
  { name_nm: "eco-friendly", color_code_nm: "#4CAF50" }
]

tags.each do |tag_attrs|
  Tag.find_or_create_by!(name_nm: tag_attrs[:name_nm]) do |tag|
    tag.assign_attributes(tag_attrs)
  end
end

puts "Created #{Tag.count} tags"

# Create 200+ realistic products
puts "Creating 200 products..."

brands = ["Nike", "Adidas", "Puma", "New Balance", "Asics", "Reebok", "Under Armour", "Converse", "Vans", "Skechers"]
athletic_models = ["Air Max", "Ultra Boost", "Gel-Kayano", "Fresh Foam", "React", "Zoom", "Free Run", "Revolution"]
casual_models = ["Chuck Taylor", "Old Skool", "Authentic", "Classic", "Original", "Heritage", "Retro"]
dress_models = ["Oxford", "Loafer", "Brogue", "Derby", "Monk Strap", "Wingtip"]
boot_models = ["Work Boot", "Hiking Boot", "Combat Boot", "Chelsea Boot", "Chukka Boot"]

products_data = []

# Athletic Shoes (80 products)
80.times do |i|
  brand = brands.sample
  model = athletic_models.sample

  products_data << {
    product_key_nm: "#{brand.upcase.gsub(' ', '-')}-#{model.upcase.gsub(' ', '-')}-#{rand(1000..9999)}",
    name_nm: "#{brand} #{model} #{['Running', 'Training', 'Cross-Training', 'Basketball', 'Tennis'].sample} Shoe",
    description_txt: "#{['Premium', 'High-performance', 'Professional', 'Advanced', 'Elite'].sample} #{model.downcase} with #{['cushioning technology', 'responsive foam', 'breathable mesh', 'lightweight design', 'superior comfort'].sample}",
    unit_price_amt: rand(80.0..250.0).round(2),
    cost_amt: rand(30.0..120.0).round(2),
    weight_num: rand(0.6..1.2).round(2),
    dimensions_json: { length: rand(28..35), width: rand(10..14), height: rand(7..12), unit: "cm" }.to_json,
    category_names: ["Athletic Shoes"],
    tag_names: ["lightweight", "breathable", "memory-foam", "cushioned"].sample(2)
  }
end

# Casual Shoes (60 products)
60.times do |i|
  brand = brands.sample
  model = casual_models.sample

  products_data << {
    product_key_nm: "#{brand.upcase.gsub(' ', '-')}-#{model.upcase.gsub(' ', '-')}-#{rand(1000..9999)}",
    name_nm: "#{brand} #{model} #{['Canvas', 'Leather', 'Suede', 'Mesh'].sample} Sneaker",
    description_txt: "#{['Classic', 'Iconic', 'Timeless', 'Vintage', 'Modern'].sample} #{model.downcase} for everyday comfort and style",
    unit_price_amt: rand(45.0..120.0).round(2),
    cost_amt: rand(20.0..60.0).round(2),
    weight_num: rand(0.5..0.9).round(2),
    dimensions_json: { length: rand(26..32), width: rand(9..13), height: rand(6..10), unit: "cm" }.to_json,
    category_names: ["Casual Shoes"],
    tag_names: ["breathable", "vegan", "durable", "comfortable"].sample(2)
  }
end

# Dress Shoes (40 products)
40.times do |i|
  model = dress_models.sample

  products_data << {
    product_key_nm: "#{model.upcase.gsub(' ', '-')}-#{['BLACK', 'BROWN', 'COGNAC'].sample}-#{rand(1000..9999)}",
    name_nm: "#{['Classic', 'Premium', 'Executive', 'Professional'].sample} #{model}",
    description_txt: "#{['Handcrafted', 'Traditional', 'Elegant', 'Sophisticated'].sample} #{model.downcase} for business and formal occasions",
    unit_price_amt: rand(150.0..400.0).round(2),
    cost_amt: rand(75.0..200.0).round(2),
    weight_num: rand(1.0..1.5).round(2),
    dimensions_json: { length: rand(30..35), width: rand(10..12), height: rand(8..11), unit: "cm" }.to_json,
    category_names: ["Dress Shoes"],
    tag_names: ["leather", "formal", "handcrafted"].sample(2)
  }
end

# Boots (20 products)
20.times do |i|
  model = boot_models.sample

  products_data << {
    product_key_nm: "#{model.upcase.gsub(' ', '-')}-#{rand(1000..9999)}",
    name_nm: "#{['Heavy-Duty', 'Professional', 'Rugged', 'Industrial'].sample} #{model}",
    description_txt: "#{['Durable', 'Weather-resistant', 'Heavy-duty', 'Professional-grade'].sample} #{model.downcase} with #{['steel toe protection', 'waterproof construction', 'slip-resistant sole', 'comfort insole'].sample}",
    unit_price_amt: rand(120.0..350.0).round(2),
    cost_amt: rand(60.0..180.0).round(2),
    weight_num: rand(1.5..2.5).round(2),
    dimensions_json: { length: rand(32..38), width: rand(12..15), height: rand(15..20), unit: "cm" }.to_json,
    category_names: ["Boots"],
    tag_names: ["waterproof", "slip-resistant", "leather", "steel-toe"].sample(2)
  }
end

products_data.each do |product_data|
  category_names = product_data.delete(:category_names)
  tag_names = product_data.delete(:tag_names)

  product = Product.find_or_create_by!(product_key_nm: product_data[:product_key_nm]) do |p|
    p.assign_attributes(product_data.except(:category_names, :tag_names))
  end

  # Associate with categories
  category_names.each do |category_name|
    category = Category.find_by(name_nm: category_name)
    product.categories << category if category && !product.categories.include?(category)
  end

  # Associate with tags
  tag_names.each do |tag_name|
    tag = Tag.find_by(name_nm: tag_name)
    product.tags << tag if tag && !product.tags.include?(tag)
  end

  # Create inventory for each product (only if not exists)
  unless product.inventory_items.where(location_nm: "WAREHOUSE-MAIN").exists?
    InventoryItem.create!(
      product: product,
      location_nm: "WAREHOUSE-MAIN",
      quantity_on_hand_cnt: rand(50..500),
      reserved_quantity_cnt: rand(0..20),
      reorder_point_cnt: 25,
      reorder_quantity_cnt: 100,
      last_counted_at: rand(30.days.ago..Time.current)
    )
  end
end

puts "Created #{Product.count} products with inventory"

# Create 500+ realistic customers
puts "Creating 500 customers..."

company_types = ["Corp", "LLC", "Inc", "Systems", "Technologies", "Solutions", "Industries", "Enterprises", "Group", "Holdings"]
company_names = [
  "Acme", "Beta", "Gamma", "Delta", "Alpha", "Omega", "Phoenix", "Titan", "Nova", "Apex",
  "Global", "United", "International", "National", "Premier", "Elite", "Prime", "Superior",
  "Advanced", "Modern", "Future", "Dynamic", "Strategic", "Innovative", "Progressive",
  "Pacific", "Atlantic", "Northern", "Southern", "Eastern", "Western", "Central",
  "Tech", "Digital", "Cyber", "Smart", "Quantum", "Neural", "Cloud", "Data", "AI",
  "Green", "Blue", "Silver", "Gold", "Diamond", "Platinum", "Crystal", "Steel"
]

first_names = [
  "John", "Jane", "Michael", "Sarah", "David", "Lisa", "Robert", "Jennifer", "William", "Jessica",
  "James", "Emily", "Christopher", "Ashley", "Daniel", "Amanda", "Matthew", "Stephanie", "Anthony", "Melissa",
  "Mark", "Nicole", "Donald", "Elizabeth", "Steven", "Helen", "Paul", "Sandra", "Andrew", "Donna",
  "Joshua", "Carol", "Kenneth", "Ruth", "Kevin", "Sharon", "Brian", "Michelle", "George", "Laura",
  "Edward", "Sarah", "Ronald", "Kimberly", "Timothy", "Deborah", "Jason", "Dorothy", "Jeffrey", "Amy"
]

last_names = [
  "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
  "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
  "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson",
  "Walker", "Young", "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
  "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell", "Carter", "Roberts"
]

cities = [
  "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego",
  "Dallas", "San Jose", "Austin", "Jacksonville", "Fort Worth", "Columbus", "Charlotte", "San Francisco",
  "Indianapolis", "Seattle", "Denver", "Washington", "Boston", "El Paso", "Nashville", "Detroit",
  "Oklahoma City", "Portland", "Las Vegas", "Memphis", "Louisville", "Baltimore", "Milwaukee", "Albuquerque"
]

states = ["CA", "TX", "FL", "NY", "PA", "IL", "OH", "GA", "NC", "MI", "NJ", "VA", "WA", "AZ", "MA", "TN", "IN", "MO", "MD", "WI"]

500.times do |i|
  company_name = "#{company_names.sample} #{company_types.sample}"
  first_name = first_names.sample
  last_name = last_names.sample

  customer = Customer.create!(
    customer_key_nm: "CUST-#{(i + 1).to_s.rjust(6, '0')}-#{rand(1000..9999)}",
    company_name_nm: company_name,
    contact_first_name_nm: first_name,
    contact_last_name_nm: last_name,
    email_nm: "#{first_name.downcase}.#{last_name.downcase}@#{company_name.downcase.gsub(' ', '')}.com",
    phone_num: "+1-#{rand(200..999)}-#{rand(200..999)}-#{rand(1000..9999)}",
    credit_limit_amt: [5000, 10000, 25000, 50000, 75000, 100000, 150000, 200000, 500000].sample,
    tax_id_num: "#{rand(10..99)}-#{rand(1000000..9999999)}",
    active_flag: [true, true, true, true, false].sample # 80% active
  )

  # Create billing address
  city = cities.sample
  state = states.sample

  customer.addresses.create!(
    address_type_nm: "billing",
    address_line1_txt: "#{rand(100..9999)} #{['Main St', 'Oak Ave', 'Business Blvd', 'Commerce Dr', 'Industrial Pkwy', 'Corporate Way'].sample}",
    address_line2_txt: rand(10) < 3 ? "Suite #{rand(100..999)}" : nil,
    city_nm: city,
    state_nm: state,
    postal_code_nm: "%05d" % rand(10000..99999),
    country_code_nm: "US",
    is_default_flag: true
  )

  # 30% chance of shipping address
  if rand(10) < 3
    customer.addresses.create!(
      address_type_nm: "shipping",
      address_line1_txt: "#{rand(100..9999)} #{['Distribution Ct', 'Warehouse Rd', 'Logistics Ln', 'Fulfillment Ave'].sample}",
      city_nm: cities.sample,
      state_nm: states.sample,
      postal_code_nm: "%05d" % rand(10000..99999),
      country_code_nm: "US",
      is_default_flag: false
    )
  end
end

puts "Created #{Customer.count} customers with addresses"

# Create realistic orders
puts "Creating orders and order line items..."

order_statuses = ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled']
customers = Customer.all
products = Product.all

# Create 1000-1500 orders over the past year
rand(1000..1500).times do |i|
  customer = customers.sample
  order_date = rand(365.days.ago..Time.current)

  order = Order.create!(
    order_key_nm: "ORD-#{Date.current.year}-#{(i + 1).to_s.rjust(6, '0')}",
    customer: customer,
    order_date_at: order_date,
    status_nm: order_statuses.sample,
    shipping_amt: rand(5.0..25.0).round(2),
    discount_amt: rand(0) < 0.3 ? rand(10.0..100.0).round(2) : 0.0 # 30% chance of discount
  )

  # Add 1-5 line items per order
  line_item_count = rand(1..5)
  total_amt = 0

  line_item_count.times do |j|
    product = products.sample
    quantity = rand(1..10)
    unit_price = product.unit_price_amt
    line_total = quantity * unit_price

    OrderLineItem.create!(
      order: order,
      product: product,
      quantity_cnt: quantity,
      unit_price_amt: unit_price,
      line_total_amt: line_total
    )

    total_amt += line_total
  end

  # Calculate final total with tax and shipping
  subtotal = total_amt
  tax_rate = rand(0.06..0.10)
  tax_amt = (subtotal * tax_rate).round(2)
  final_total = subtotal + tax_amt + order.shipping_amt - order.discount_amt

  order.update!(
    subtotal_amt: subtotal.round(2),
    tax_amt: tax_amt,
    total_amt: final_total.round(2)
  )
end

puts "Created #{Order.count} orders with #{OrderLineItem.count} line items"

puts "\n=== REALISTIC SAMPLE DATA CREATED SUCCESSFULLY ==="
puts "Categories: #{Category.count}"
puts "Tags: #{Tag.count}"
puts "Products: #{Product.count}"
puts "Customers: #{Customer.count}"
puts "Addresses: #{Address.count}"
puts "Orders: #{Order.count}"
puts "Order Line Items: #{OrderLineItem.count}"
puts "\n🎉 Now you can properly test:"
puts "- Pagination (500 customers, 200+ products, 1000+ orders)"
puts "- Filtering and sorting with real data variety"
puts "- Performance with realistic data volumes"
puts "\n🔗 Test URLs:"
puts "- Customers: http://localhost:3000/customers"
puts "- Products: http://localhost:3000/products (when implemented)"
puts "- Orders: http://localhost:3000/orders (when implemented)"
