package store

func Fill(c *Cache, keys []string) {
	for _, k := range keys {
		c.Put(Normalize(k))
	}
}
