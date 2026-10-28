
export default function Home() {
  return (
    <main className="min-h-screen bg-[#151719] text-white">
      <header className="mx-auto flex max-w-6xl items-center justify-between px-6 py-6">
        <h1 className="text-2xl font-bold tracking-tight">
          Learn<span className="text-lime-400">-It</span>
        </h1>

        <span className="text-sm text-gray-400">
          Your learning space
        </span>
      </header>

      <section className="mx-auto flex max-w-4xl flex-col items-center px-6 py-28 text-center">
        <div className="mb-6 rounded-full border border-lime-400/30 bg-lime-400/10 px-4 py-2 text-sm text-lime-400">
          Learn smarter, every day
        </div>

        <h2 className="text-5xl font-bold tracking-tight sm:text-7xl">
          Make learning
          <span className="block text-lime-400">
            stick.
          </span>
        </h2>

        <p className="mt-6 max-w-xl text-lg leading-relaxed text-gray-400">
          Create flashcards, test your knowledge,
          and turn studying into something you
          actually enjoy.
        </p>

        <div className="mt-14 grid w-full gap-4 sm:grid-cols-3">
          {[
            ["Flashcards", "Create and review your cards"],
            ["Practice Tests", "Challenge your knowledge"],
            ["Match", "Learn through interactive games"],
          ].map(([title, description]) => (
            <div
              key={title}
              className="rounded-2xl border border-white/10 bg-white/5 p-6 text-left"
            >
              <h3 className="font-semibold text-lime-400">
                {title}
              </h3>
              <p className="mt-2 text-sm text-gray-400">
                {description}
              </p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
