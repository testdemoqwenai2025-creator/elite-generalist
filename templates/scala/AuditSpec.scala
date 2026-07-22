// =============================================================================
//  AuditSpec.scala
//  -----------------------------------------------------------------------------
//  ScalaCheck properties for the Audit pipeline.  If any of these fails the
//  binary does not ship.
// =============================================================================

package elite.audit

import org.scalacheck.{Gen, Properties, Prop}
import org.scalacheck.Prop.{forAll, BooleanOperators}

import java.util.concurrent.atomic.AtomicLong

object AuditSpec extends Properties("Audit"):

  // ----------------- Arbitrary generators -----------------

  private val currencyGen: Gen[Currency] =
    Gen.oneOf(Currency.EUR, Currency.USD, Currency.GBP, Currency.JPY)

  private def idGen(prefix: String): Gen[String] =
    Gen.oneOf((1 to 20).map(i => s"$prefix-$i"))

  private val txGen: Gen[Transaction] =
    for
      id    <- idGen("tx")
      actor <- idGen("actor")
      uid   <- idGen("u")
      amt   <- Gen.choose(-1_000_000L, 1_000_000L)
      cur   <- currencyGen
      ts    <- Gen.choose(0L, 1_700_000_000L)
    yield Transaction(TxId(id), ActorId(actor), UserId(uid), Cents(amt), cur, ts, "")

  private val userGen: Gen[User] =
    for
      uid <- idGen("u")
    yield User(UserId(uid), s"Name-$uid", "a@b", "FR")

  // ----------------- THEOREMS -----------------

  property("audit preserves total credit/debit sums") =
    forAll(Gen.listOf(userGen), Gen.listOf(txGen)) { (users, txs) =>
      val r = auditLedger(0L, users)(txs)
      val sumPos = txs.filter(_.amount > Cents.zero).map(_.amount).foldLeft(Cents.zero)(Cents.+)
      val sumNeg = txs.filter(_.amount < Cents.zero).map(_.amount).foldLeft(Cents.zero)(Cents.+)
      (r.totalCredits == sumPos) :| "credits" && (r.totalDebits == sumNeg) :| "debits"
    }

  property("audit never loses a user") =
    forAll(Gen.listOf(userGen), Gen.listOf(txGen)) { (users, txs) =>
      val r = auditLedger(0L, users)(txs)
      val in  = txs.map(_.userId).filter(_.value.nonEmpty).toSet
      val out = r.allSummaries.map(_.userId).toSet
      in == out
    }

  property("audit is deterministic") =
    forAll(Gen.listOf(userGen), Gen.listOf(txGen)) { (users, txs) =>
      auditLedger(0L, users)(txs) == auditLedger(0L, users)(txs)
    }

  property("normalize drops empty user ids") =
    forAll(Gen.listOf(txGen)) { txs =>
      val withEmpty = Transaction(TxId("x"), ActorId("a"), UserId(""), Cents(0L), Currency.EUR, 0L, "") +: txs
      normalize(withEmpty).forall(_.userId.value.nonEmpty)
    }
