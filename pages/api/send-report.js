import sendgrid from '@sendgrid/mail'
import fetch from 'node-fetch'

sendgrid.setApiKey(process.env.SENDGRID_API_KEY || '')

export default async function handler(req, res) {
  const secret = req.headers['x-report-secret'] || req.query.secret
  if (!secret || secret !== process.env.REPORT_SECRET) {
    return res.status(401).json({ error: 'unauthorized' })
  }

  // In a real app we'd query Supabase for sales data and generate CSV
  const csv = 'date,product,region,amount\n2026-08-01,Widget A,Tokyo,1000'

  const msg = {
    to: (process.env.ADMIN_EMAILS || '').split(','),
    from: 'noreply@example.com',
    subject: 'Scheduled Sales Report',
    text: 'Attached is the scheduled sales report.',
    attachments: [
      {
        content: Buffer.from(csv).toString('base64'),
        filename: 'report.csv',
        type: 'text/csv',
        disposition: 'attachment'
      }
    ]
  }

  try {
    await sendgrid.send(msg)
    return res.status(200).json({ ok: true })
  } catch (err) {
    console.error(err)
    return res.status(500).json({ error: 'send failed', detail: String(err) })
  }
}
