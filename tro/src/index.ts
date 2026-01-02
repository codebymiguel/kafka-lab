import { Kafka } from "kafkajs";

type MsgType = "PING" | "PONG" | "ACK" | "EVENT";
type Source = "BLI" | "TRO";

interface BusMessage<T = any> {
  type: MsgType;
  correlationId: string;
  source: Source;
  timestamp: string;
  payload: T;
}

const kafka = new Kafka({
  clientId: "tro",
  brokers: ["localhost:9092"],
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: "tro-group" });

const IN_TOPIC = "bli.to.tro";
const OUT_TOPIC = "tro.to.bli";

function newId() {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function nowIso() {
  return new Date().toISOString();
}

function encode(msg: BusMessage): string {
  return JSON.stringify(msg);
}

function decode(raw: string): BusMessage | null {
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function send(msg: BusMessage) {
  await producer.send({
    topic: OUT_TOPIC,
    messages: [{ value: encode(msg) }],
  });
}

async function main() {
  await producer.connect();
  await consumer.connect();

  await consumer.subscribe({ topic: IN_TOPIC, fromBeginning: true });

  await consumer.run({
    eachMessage: async ({ topic, message }) => {
      const raw = message.value?.toString() ?? "";
      const msg = decode(raw);

      if (!msg) {
        console.log(`[TRO] recebi lixo/nao-JSON em ${topic}:`, raw);
        return;
      }

      console.log(`[TRO] recebi ${msg.type} de ${msg.source} corr=${msg.correlationId}`, msg.payload);

      // Regra anti-loop: ACK nunca gera ACK
      if (msg.type === "ACK") return;

      // Regras de teste:
      // - Se receber PONG, responde ACK
      // - Se receber PING, responde PONG
      if (msg.type === "PING") {
        await send({
          type: "PONG",
          correlationId: msg.correlationId,
          source: "TRO",
          timestamp: nowIso(),
          payload: { replyTo: "PING", note: "pong from TRO" },
        });
        console.log(`[TRO] enviei PONG corr=${msg.correlationId}`);
        return;
      }

      if (msg.type === "PONG") {
        await send({
          type: "ACK",
          correlationId: msg.correlationId,
          source: "TRO",
          timestamp: nowIso(),
          payload: { ok: true, note: "ack from TRO" },
        });
        console.log(`[TRO] enviei ACK corr=${msg.correlationId}`);
        return;
      }
    },
  });

  // Mensagem inicial (teste): envia EVENT e espera ACK do BLI
  const corr = newId();
  await send({
    type: "EVENT",
    correlationId: corr,
    source: "TRO",
    timestamp: nowIso(),
    payload: { event: "TRO_STARTED" },
  });
  console.log(`[TRO] enviei EVENT corr=${corr}`);
}

main().catch((e) => {
  console.error("[TRO] erro:", e);
  process.exit(1);
});
