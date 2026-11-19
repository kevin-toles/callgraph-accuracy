def slugify(text):
    return text.lower()


def title_slug(text):
    return slugify(text.title())
