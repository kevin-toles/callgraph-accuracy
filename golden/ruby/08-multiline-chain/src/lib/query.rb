class Query
  def build(rel)
    rel
      .where(1)
      .order(2)
      .limit(3)
  end

  def nested(db)
    db.execute(
      compile(db.table())
    ).rows()
  end

  def compile(t)
    t
  end
end
