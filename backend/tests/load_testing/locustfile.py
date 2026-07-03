import random
from locust import HttpUser, task, between, SequentialTaskSet


class CustomerFlow(SequentialTaskSet):
    """Sequence of tasks representing a user loading the app, browsing products,
    placing an order, and tracking its progress.
    """

    def on_start(self):
        # Perform mock/setup token-based auth
        self.headers = {"Accept": "application/json"}
        self.auth_token = None
        self.user_id = None
        self.order_id = None
        self.login()

    def login(self):
        # Simulate registration/login or using a pool of test credentials
        # For simulation, we attempt to register a random user or login if credentials match
        username = f"loadtest_{random.randint(10000, 99999)}@hdktest.com"
        password = "securepassword123"
        phone = f"998877{random.randint(1000, 9999)}"

        # Attempt registration
        with self.client.post(
            "/api/v1/auth/register/",
            json={
                "phone_number": phone,
                "password": password,
                "name": "Load Test User",
            },
            headers=self.headers,
            catch_response=True,
        ) as response:
            if response.status_code in [200, 201]:
                data = response.json()
                self.auth_token = data.get("access")
                self.headers["Authorization"] = f"Bearer {self.auth_token}"
                response.success()
            else:
                # If registration fails (e.g. phone already exists), fallback to login
                with self.client.post(
                    "/api/v1/auth/login/",
                    json={"phone_number": phone, "password": password},
                    headers=self.headers,
                    catch_response=True,
                ) as login_res:
                    if login_res.status_code == 200:
                        data = login_res.json()
                        self.auth_token = data.get("access")
                        self.headers["Authorization"] = f"Bearer {self.auth_token}"
                        login_res.success()
                    else:
                        login_res.failure("Could not authenticate load test user")

    @task
    def browse_menu(self):
        """Fetches product categories and listings."""
        self.client.get("/api/v1/categories/", headers=self.headers)
        self.client.get("/api/v1/products/", headers=self.headers)

    @task
    def view_product_details(self):
        """Simulates viewing details of a couple of products."""
        # Query product lists, then view details for first few products
        res = self.client.get("/api/v1/products/", headers=self.headers)
        if res.status_code == 200:
            products = res.json()
            if products and len(products) > 0:
                product_id = products[0]["id"]
                self.client.get(f"/api/v1/products/{product_id}/", headers=self.headers)

    @task
    def check_coins(self):
        """Queries the current user's coins balance."""
        self.client.get("/api/v1/profile/", headers=self.headers)

    @task
    def place_order(self):
        """Adds product to cart and places an order."""
        res = self.client.get("/api/v1/products/", headers=self.headers)
        if res.status_code == 200:
            products = res.json()
            if products and len(products) > 0:
                product_id = products[0]["id"]

                # Fetch delivery addresses
                address_res = self.client.get(
                    "/api/v1/addresses/", headers=self.headers
                )
                address_id = None

                if address_res.status_code == 200:
                    addresses = address_res.json()
                    if addresses and len(addresses) > 0:
                        address_id = addresses[0]["id"]

                # Create a default address if none exist
                if not address_id:
                    addr_data = {
                        "name": "Home",
                        "line1": "123 Load Test Street",
                        "latitude": 17.3850,
                        "longitude": 78.4867,
                    }
                    create_addr_res = self.client.post(
                        "/api/v1/addresses/", json=addr_data, headers=self.headers
                    )
                    if create_addr_res.status_code in [200, 201]:
                        address_id = create_addr_res.json().get("id")

                if address_id:
                    order_payload = {
                        "address_id": address_id,
                        "payment_method": "cod",
                        "items": [{"product_id": product_id, "quantity": 1}],
                        "delivery_notes": "Locust Load Test",
                        "redeem_coins": False,
                    }

                    order_res = self.client.post(
                        "/api/v1/orders/create/",
                        json=order_payload,
                        headers=self.headers,
                    )
                    if order_res.status_code in [200, 201]:
                        self.order_id = order_res.json().get("id")

    @task
    def poll_order_tracking(self):
        """Simulates polling the active order status every few seconds."""
        if self.order_id:
            # Poll status 3 times to simulate checking order state advances
            for _ in range(3):
                self.client.get(
                    f"/api/v1/orders/{self.order_id}/", headers=self.headers
                )
                self.interrupt(behavior=False)  # sleep between polling tasks

    @task
    def complete_session(self):
        """Resets flow for the next virtual user session."""
        self.interrupt()


class HDKFoodsLoadTestUser(HttpUser):
    """Simulates realistic user load with wait times between actions."""

    tasks = [CustomerFlow]
    wait_time = between(1.5, 4.0)
