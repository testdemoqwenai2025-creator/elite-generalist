// Scala 3 build, sbt. Three direct deps.
ThisBuild / scalaVersion := "3.4.2"
ThisBuild / organization := "elite.audit"
ThisBuild / version      := "0.1.0"

val zioVersion         = "2.1.3"
val zioJsonVersion     = "0.6.2"
val scalacheckVersion  = "1.17.0"

lazy val root = (project in file("."))
  .settings(
    name := "elite-audit",
    libraryDependencies ++= Seq(
      "dev.zio"             %% "zio"          % zioVersion,
      "dev.zio"             %% "zio-json"     % zioJsonVersion,
      "org.scalacheck"      %% "scalacheck"   % scalacheckVersion % Test
    ),
    // Phase 4 — package.  Reproducible, single static binary.
    Compile / nativeImage ~= { _.withName("elite-audit") },
    // Compile error on any unused import — keeps the dependency surface clean.
    scalacOptions ++= Seq(
      "-Wunused:imports",
      "-Werror",
      "-deprecation",
      "-feature"
    )
  )
