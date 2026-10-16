from zalpro_api.models import Order

CURRENCY_LABELS = {"UZS": "so'm", "USD": "$"}


def format_money(amount: int, currency: str) -> str:
    grouped = f"{amount:,}".replace(",", " ")
    return f"{grouped} {CURRENCY_LABELS.get(currency, currency)}"


def order_title(order: Order) -> str:
    extra = ", ".join(part for part in (order.size, order.color) if part)
    return f"{order.product_name} ({extra})" if extra else order.product_name


def order_created_text(order: Order) -> str:
    total = format_money(order.price * order.qty, order.currency)
    return f"🛒 Buyurtma: {order_title(order)} × {order.qty} — {total}"


def order_given_text(order: Order) -> str:
    total = format_money(order.price * order.qty, order.currency)
    return f"✅ Buyurtma berildi: {order_title(order)} × {order.qty} — {total}"


def order_canceled_text(order: Order) -> str:
    return f"❌ Buyurtma bekor qilindi: {order_title(order)}"


def reminder_text(days_left: int) -> str:
    if days_left <= 0:
        return "⏰ Abonementingiz tugadi — yangilang"
    return f"⏰ Abonementingiz {days_left} kundan keyin tugaydi"
