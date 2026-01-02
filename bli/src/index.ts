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
  clientId: "bli",
  brokers: ["localhost:9092"],
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: "bli-group" });

const IN_TOPIC = "tro.to.bli";
const OUT_TOPIC = "bli.to.tro";

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
        console.log(`[BLI] recebi lixo/nao-JSON em ${topic}:`, raw);
        return;
      }

      console.log(`[BLI] recebi ${msg.type} de ${msg.source} corr=${msg.correlationId}`, msg.payload);

      // Regra anti-loop: ACK nunca gera ACK
      if (msg.type === "ACK") return;

      // Regras de teste:
      // - Se receber PING, responde PONG
      // - Se receber EVENT, responde ACK (1 vez)
      if (msg.type === "PING") {
        await send({
          type: "PONG",
          correlationId: msg.correlationId, // mantém o mesmo
          source: "BLI",
          timestamp: nowIso(),
          payload: { replyTo: "PING", note: "pong from BLI" },
        });
        console.log(`[BLI] enviei PONG corr=${msg.correlationId}`);
        return;
      }

      if (msg.type === "EVENT") {
        await send({
          type: "ACK",
          correlationId: msg.correlationId,
          source: "BLI",
          timestamp: nowIso(),
          payload: { ok: true },
        });
        console.log(`[BLI] enviei ACK corr=${msg.correlationId}`);
        return;
      }
    },
  });

  // Mensagem inicial (teste): envia PING
  const corr = newId();
  await send({
    type: "PING",
    correlationId: corr,
    source: "BLI",
    timestamp: nowIso(),
    payload: { hello: "from BLI" },
  });
  console.log(`[BLI] enviei PING corr=${corr}`);
}

main().catch((e) => {
  console.error("[BLI] erro:", e);
  process.exit(1);
});
