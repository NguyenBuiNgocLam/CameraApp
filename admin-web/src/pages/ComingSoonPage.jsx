export default function ComingSoonPage({ title }) {
  return (
    <section>
      <h2 className="text-2xl font-bold text-slate-950">{title}</h2>
      <div className="mt-6 rounded-lg border border-dashed border-slate-300 bg-white p-8 text-center">
        <p className="text-sm font-medium text-slate-700">This page is scheduled for a later batch.</p>
      </div>
    </section>
  );
}
