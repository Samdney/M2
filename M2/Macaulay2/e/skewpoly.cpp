// Copyright 2003 Michael E. Stillman

#include "skewpoly.hpp"
#include "gbring.hpp"
#include "skew.hpp"

SkewPolynomialRing::~SkewPolynomialRing()
{
}

bool SkewPolynomialRing::initialize_skew(M2_arrayint skewvars)
{
  is_skew_ = true;
  skew_ = SkewMultiplication(nvars_, skewvars->len, skewvars->array);
  return true;
}

SkewPolynomialRing *SkewPolynomialRing::create(const Ring *K,
                                               const Monoid *M,
                                               M2_arrayint skewvars)
{
  SkewPolynomialRing *result = new SkewPolynomialRing;

  result->initialize_poly_ring(K,M);
  if (!result->initialize_skew(skewvars)) return 0;
  result->gb_ring_ = GBRing::create_SkewPolynomialRing(K,M,result->skew_);
  return result;
}

void SkewPolynomialRing::text_out(buffer &o) const
{
  o << "SkewPolynomialRing(";
  K_->text_out(o);
  M_->text_out(o);
  o << ")";
}

ring_elem SkewPolynomialRing::mult_by_term(const ring_elem f,
                                               const ring_elem c,
                                               const int *m) const
  // Computes c*m*f, BUT NOT doing normal form wrt a quotient ideal..
{
  Nterm head;
  Nterm *inresult = &head;

  exponents EXP1 = ALLOCATE_EXPONENTS(exp_size);
  exponents EXP2 = ALLOCATE_EXPONENTS(exp_size);
  M_->to_expvector(m, EXP1);

  for (Nterm *s = f; s != NULL; s = s->next)
    {
      M_->to_expvector(s->monom, EXP2);
      int sign = skew_.mult_sign(EXP1, EXP2);
      if (sign == 0) continue;

      Nterm *t = new_term();
      t->next = 0;
      t->coeff = K_->mult(c, s->coeff);
      if (sign < 0)
        K_->negate_to(t->coeff);

      M_->mult(m, s->monom, t->monom);
      inresult->next = t;
      inresult = inresult->next;
    }
  inresult->next = 0;
  return head.next;
}


ring_elem SkewPolynomialRing::power(const ring_elem f, mpz_t n) const
{
  int n1;
  if (RingZZ::get_si(n1,n))
    return power(f,n1);
  else
    {
      ERROR("exponent too large");
      return ZERO_RINGELEM;
    }
}

ring_elem SkewPolynomialRing::power(const ring_elem f, int n) const
{
  return Ring::power(f,n);
}


// Local Variables:
// compile-command: "make -C $M2BUILDDIR/Macaulay2/e "
// indent-tabs-mode: nil
// End:
