import sys
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict
from supabase import Client, create_client


# --------------------------------------------------
# Configuration
# --------------------------------------------------

BACKEND_DIR = Path(__file__).resolve().parents[1]
ROOT_DIR = BACKEND_DIR.parent

sys.path.insert(0, str(BACKEND_DIR))


class SeederSettings(BaseSettings):
    supabase_url: str
    supabase_service_role_key: str
    demo_user_password: str

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        extra="ignore",
    )


settings = SeederSettings()

supabase: Client = create_client(
    settings.supabase_url,
    settings.supabase_service_role_key,
)


# --------------------------------------------------
# Demo data
# --------------------------------------------------

DEMO_USERS = [
    {
        "email": "admin@litebooks.test",
        "full_name": "System Administrator",
        "company": {
            "company_name": "LiteBooks Trading",
            "company_code": "LBT",
            "address": "Manila, Philippines",
            "contact_number": "09171234567",
            "email": "admin@litebooks.test",
            "currency": "PHP",
            "fiscal_year_start": 1,
        },
    },
    {
        "email": "owner@litebooks.test",
        "full_name": "Juan Dela Cruz",
        "company": {
            "company_name": "Juan's General Merchandise",
            "company_code": "JGM",
            "address": "Quezon City, Philippines",
            "contact_number": "09181234567",
            "email": "owner@litebooks.test",
            "currency": "PHP",
            "fiscal_year_start": 1,
        },
    },
    {
        "email": "business@litebooks.test",
        "full_name": "Maria Santos",
        "company": {
            "company_name": "Santos Retail Store",
            "company_code": "SRS",
            "address": "Caloocan City, Philippines",
            "contact_number": "09191234567",
            "email": "business@litebooks.test",
            "currency": "PHP",
            "fiscal_year_start": 1,
        },
    },
]


# --------------------------------------------------
# User helpers
# --------------------------------------------------

def find_existing_user(email: str):
    page = 1

    while True:
        response = supabase.auth.admin.list_users(
            page=page,
            per_page=1000,
        )

        users = response if isinstance(response, list) else response.users

        for user in users:
            if user.email and user.email.lower() == email.lower():
                return user

        if len(users) < 1000:
            return None

        page += 1


def create_or_get_user(user_data: dict):
    email = user_data["email"]

    existing_user = find_existing_user(email)

    if existing_user:
        print(f"[EXISTS] User: {email}")

        # Ensure existing demo users are confirmed.
        if not existing_user.email_confirmed_at:
            supabase.auth.admin.update_user_by_id(
                existing_user.id,
                {"email_confirm": True},
            )
            print(f"[CONFIRMED] User: {email}")

        return existing_user

    response = supabase.auth.admin.create_user(
        {
            "email": email,
            "password": settings.demo_user_password,
            "email_confirm": True,
            "user_metadata": {
                "full_name": user_data["full_name"],
            },
        }
    )

    print(f"[CREATED] User: {email}")

    return response


# --------------------------------------------------
# Company helpers
# --------------------------------------------------

def create_or_get_company(user_id: str, company_data: dict):
    company_code = company_data["company_code"]

    existing_company = (
        supabase.table("companies")
        .select("id, company_name, company_code")
        .eq("owner_id", user_id)
        .eq("company_code", company_code)
        .maybe_single()
        .execute()
    )

    if existing_company.data:
        print(f"[EXISTS] Company: {company_data['company_name']}")
        return existing_company.data

    payload = {
        **company_data,
        "owner_id": user_id,
    }

    response = (
        supabase.table("companies")
        .insert(payload)
        .execute()
    )

    print(f"[CREATED] Company: {company_data['company_name']}")

    return response.data[0]


# --------------------------------------------------
# Seeder execution
# --------------------------------------------------

def run_seeder():
    print("\n====================================")
    print(" LiteBooks Demo Data Seeder")
    print("====================================\n")

    for user_data in DEMO_USERS:
        try:
            user = create_or_get_user(user_data)

            create_or_get_company(
                user_id=str(user.id),
                company_data=user_data["company"],
            )

            print()

        except Exception as exc:
            print(f"[ERROR] {user_data['email']}: {exc}")
            raise

    print("====================================")
    print(" Demo data seeding completed.")
    print("====================================")


if __name__ == "__main__":
    run_seeder()