function fixEmail(email) {
  return email.replace('@', ".at.") + "@kitsd.com";
}

db.users.find(
  {email: {$regex: /@(?!(kitsd|bodireel))/i}}
).forEach(
  function (u) {
    u.email = fixEmail(u.email);
    u._email = fixEmail(u._email);
    u.__email = fixEmail(u.__email);
    db.users.save(u);
  }
);
