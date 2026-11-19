def build(query):
    return (
        query
        .filter(active=True)
        .order_by("name")
        .limit(10)
    )


def nested(session):
    return session.execute(
        build(
            session.query()
        )
    ).all()
