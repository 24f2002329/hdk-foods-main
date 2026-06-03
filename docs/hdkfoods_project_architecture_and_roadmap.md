# HDK Foods — Complete Project Architecture & Development Roadmap

## Project Overview

HDK Foods is a cloud kitchen ordering and management platform being built for a small city food business.

The goal is to create:

- A professional customer ordering website
- Internal dashboards for admin, chef, and delivery staff
- Payment integration
- Order tracking system
- Scalable backend architecture
- Modern deployment workflow with CI/CD

The system is being designed in a way that:

- is easy to build now
- works on low budget
- scales later without major rewrites
- uses modern production-grade architecture

---

# Current Status (Already Completed)

## 1. Domain & Branding

Completed:

- Domain purchased:
  - `hdkfoods.in`

- Business email setup:
  - `hello@hdkfoods.in`

- Titan Email configured

---

## 2. DNS & Cloudflare Setup

Completed:

- Domain connected to Cloudflare via nameservers
- Cloudflare active
- Email DNS records configured:
  - MX
  - SPF
  - DKIM
  - DMARC

Benefits gained:

- CDN
- HTTPS
- DNS management
- DDoS protection
- SSL certificates
- Faster global delivery

---

## 3. GitHub & Development Workflow

Completed:

- GitHub repository created
- Git initialized
- CI/CD foundation started
- GitHub Codespaces configured

Benefits:

- Cloud-based development
- Auto-saving environment
- Git version control
- Easy collaboration
- Production deployment pipeline ready

---

## 4. Frontend Deployment Infrastructure

Completed:

- Cloudflare Pages configured
- GitHub repository connected
- Auto deployment working
- CI/CD for frontend active

Frontend deployment flow:

```text
Git Push
↓
Cloudflare Pages Auto Build
↓
Production Deployment
```

Frontend URL:

```text
https://hdkfoods.in
```

---

# Final Recommended Architecture

## Frontend

Hosted on:

- Cloudflare Pages

Responsibilities:

- Customer website
- Menu display
- Cart UI
- Checkout UI
- Order tracking UI
- Staff dashboards
- PWA support

Tech Stack:

- HTML
- Tailwind CSS
- JavaScript

Future upgrade:

- React / Next.js

---

# Backend

Hosted on:

- Azure App Service

Backend URL:

```text
https://api.hdkfoods.in
```

Tech Stack:

- Django
- Django REST Framework

Responsibilities:

- Business logic
- APIs
- Order handling
- Payment verification
- Role management
- Analytics
- Notifications
- Security

---

# Database & Authentication

Using:

- Supabase PostgreSQL
- Supabase Auth

Why Supabase?

- Managed PostgreSQL
- Easy authentication
- Low maintenance
- Free tier sufficient initially
- Fast MVP development

Supabase Responsibilities:

- User authentication
- Database hosting
- Session handling
- Password hashing

---

# Payments

Using:

- Razorpay

Supported payment methods:

- UPI
- Cards
- Wallets
- Net banking
- COD

Why Razorpay?

- Automatic payment verification
- Secure callbacks
- UPI integration
- Order-payment linking
- Easy integration

---

# Final System Flow

```text
Frontend (Cloudflare Pages)
        ↓
Django Backend API (Azure)
        ↓
Supabase PostgreSQL Database
```

---

# User Roles

## 1. Customer

Can:

- Browse menu
- Add items to cart
- Place order
- Make payment
- Track order
- View order history

---

## 2. Admin

Can:

- Add/edit products
- Change prices
- Manage categories
- View analytics
- Manage orders
- Create staff accounts
- Control availability

---

## 3. Chef / Kitchen Staff

Can:

- View incoming orders
- Update cooking status
- Mark orders ready

---

## 4. Delivery Staff

Can:

- View assigned orders
- Update delivery status
- Mark delivered

---

# Order Lifecycle

## Minimal Tracking System

```text
Order Received
↓
Preparing
↓
Out for Delivery
↓
Delivered
```

This is intentionally simple for MVP.

No live GPS tracking initially.

---

# Payment Flow

```text
Customer clicks Pay
↓
Frontend requests Razorpay order from backend
↓
Backend creates Razorpay order
↓
Customer pays via UPI/Card
↓
Razorpay verifies payment
↓
Backend receives payment confirmation
↓
Order marked PAID
```

Important:

Payment verification always happens on backend.

---

# Authentication Strategy

## Current Plan

Using:

- Supabase Auth

Authentication methods:

### Customers

Initially:

- Guest checkout
- Optional account

Later:

- OTP login
- Loyalty system

### Staff

- Email + password

---

# Role-Based Access Control (RBAC)

Single user system with roles:

```text
customer
admin
chef
delivery
```

Backend checks permissions before allowing actions.

---

# Dashboard Structure

## Customer Frontend

```text
/
/menu
/cart
/checkout
/track-order
/my-orders
```

---

## Admin Dashboard

```text
/admin
```

Features:

- Product management
- Order management
- Analytics
- Staff management

---

## Chef Dashboard

```text
/chef
```

Features:

- Incoming orders
- Status updates
- Kitchen workflow

---

## Delivery Dashboard

```text
/delivery
```

Features:

- Assigned deliveries
- Delivery updates

---

# Database Design (Initial)

## Users

```text
id
name
phone
role
email
```

---

## Products

```text
id
name
price
description
image
category
available
```

---

## Orders

```text
id
customer
status
payment_status
total_price
created_at
updated_at
```

---

## Order Items

```text
order_id
product_id
quantity
price
```

---

# CI/CD Workflow

## Frontend

```text
GitHub Push
↓
Cloudflare Pages Build
↓
Production Deployment
```

---

## Backend

```text
GitHub Push
↓
Azure App Service Deployment
↓
Backend Updated
```

---

# Why This Architecture Was Chosen

## Avoided Problems

Avoided:

- Heavy DevOps
- Complex Kubernetes setup
- Managing databases manually
- Overengineering
- Large cloud costs
- Difficult scaling paths

---

# Benefits of Current Architecture

## Easy Now

- Faster MVP development
- Lower maintenance
- Low infrastructure cost
- Beginner friendly

---

## Scalable Later

- Django backend already exists
- PostgreSQL already used
- APIs centralized
- Frontend separated cleanly
- Easy future expansion

---

# Things Intentionally NOT Being Built Initially

To avoid complexity, these are postponed:

- Live GPS tracking
- Native mobile apps
- AI recommendations
- Complex inventory systems
- Microservices
- Real-time delivery maps
- Advanced analytics

---

# MVP Scope (Phase 1)

## Customer Features

- Home page
- Menu
- Cart
- Checkout
- Razorpay payments
- COD support
- Order tracking
- Order history

---

## Staff Features

- Product management
- Order management
- Status updates

---

# Phase 2 Features

Later additions:

- OTP login
- Notifications
- Coupons
- Loyalty system
- Better analytics
- PWA installation support

---

# Phase 3 Features

Future scaling:

- Native apps
- AI features
- Inventory automation
- Multiple branches
- ERP features

---

# Immediate Next Steps

## 1. Backend Infrastructure

Create:

- Azure App Service
- `api.hdkfoods.in`

---

## 2. Setup Django Backend

Implement:

- Django REST Framework
- Supabase connection
- Auth verification
- API architecture

---

## 3. Product APIs

Create:

- Product CRUD APIs
- Category APIs
- Availability management

---

## 4. Order APIs

Create:

- Place order
- Track order
- Order history
- Status updates

---

## 5. Payment Integration

Integrate:

- Razorpay checkout
- Payment verification
- Payment status updates

---

## 6. Dashboard Frontends

Build:

- Admin dashboard
- Chef dashboard
- Delivery dashboard

---

# Long-Term Goal

Build a modern cloud kitchen platform that:

- handles real customers
- processes real payments
- manages real orders
- scales professionally
- becomes both:
  - a real business
  - a strong portfolio/startup-grade project

