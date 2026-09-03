package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

var (
	uuidPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)
	hashPattern = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// Anchor é registro mínimo permitido on-chain pelo Doc 11. Payload completo
// permanece no Postgres; campos livres e dados pessoais não entram no ledger.
type Anchor struct {
	EventID      string `json:"eventId"`
	PayloadHash  string `json:"payloadHash"`
	Function     string `json:"function"`
	Organization string `json:"organization"`
	Transaction  string `json:"transactionId"`
	OccurredAt   string `json:"occurredAt"`
}

type AnchorContract struct {
	contractapi.Contract
}

func (c *AnchorContract) RecordEvent(ctx contractapi.TransactionContextInterface, eventID, payloadHash string) (*Anchor, error) {
	return c.record(ctx, "RecordEvent", eventID, payloadHash)
}

func (c *AnchorContract) RegisterAnimal(ctx contractapi.TransactionContextInterface, eventID, payloadHash string) (*Anchor, error) {
	return c.record(ctx, "RegisterAnimal", eventID, payloadHash)
}

func (c *AnchorContract) LinkPhysicalIdentifier(ctx contractapi.TransactionContextInterface, eventID, payloadHash string) (*Anchor, error) {
	return c.record(ctx, "LinkPhysicalIdentifier", eventID, payloadHash)
}

func (c *AnchorContract) ReidentifyAnimal(ctx contractapi.TransactionContextInterface, eventID, payloadHash string) (*Anchor, error) {
	return c.record(ctx, "ReidentifyAnimal", eventID, payloadHash)
}

func (c *AnchorContract) RecordHealthEvent(ctx contractapi.TransactionContextInterface, eventID, payloadHash string) (*Anchor, error) {
	return c.record(ctx, "RecordHealthEvent", eventID, payloadHash)
}

func (c *AnchorContract) RecordMovement(ctx contractapi.TransactionContextInterface, eventID, payloadHash string) (*Anchor, error) {
	return c.record(ctx, "RecordMovement", eventID, payloadHash)
}

func (c *AnchorContract) CorrectEvent(ctx contractapi.TransactionContextInterface, eventID, payloadHash string) (*Anchor, error) {
	return c.record(ctx, "CorrectEvent", eventID, payloadHash)
}

func (c *AnchorContract) VerifyProof(ctx contractapi.TransactionContextInterface, eventID string) (*Anchor, error) {
	if !uuidPattern.MatchString(eventID) {
		return nil, fmt.Errorf("eventId inválido")
	}

	data, err := ctx.GetStub().GetState(anchorKey(eventID))
	if err != nil {
		return nil, fmt.Errorf("ler âncora: %w", err)
	}
	if data == nil {
		return nil, fmt.Errorf("âncora não encontrada")
	}

	var anchor Anchor
	if err := json.Unmarshal(data, &anchor); err != nil {
		return nil, fmt.Errorf("decodificar âncora: %w", err)
	}
	return &anchor, nil
}

func (c *AnchorContract) record(ctx contractapi.TransactionContextInterface, function, eventID, payloadHash string) (*Anchor, error) {
	if !uuidPattern.MatchString(eventID) {
		return nil, fmt.Errorf("eventId inválido")
	}
	if !hashPattern.MatchString(payloadHash) {
		return nil, fmt.Errorf("payloadHash inválido")
	}

	key := anchorKey(eventID)
	existing, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("ler âncora: %w", err)
	}
	if existing != nil {
		var anchor Anchor
		if err := json.Unmarshal(existing, &anchor); err != nil {
			return nil, fmt.Errorf("decodificar âncora existente: %w", err)
		}
		if anchor.PayloadHash != payloadHash {
			return nil, fmt.Errorf("eventId já ancorado com outro payloadHash")
		}
		return &anchor, nil
	}

	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return nil, fmt.Errorf("obter MSP: %w", err)
	}
	timestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return nil, fmt.Errorf("obter timestamp: %w", err)
	}

	anchor := &Anchor{
		EventID:      eventID,
		PayloadHash:  payloadHash,
		Function:     function,
		Organization: mspID,
		Transaction:  ctx.GetStub().GetTxID(),
		OccurredAt:   time.Unix(timestamp.Seconds, int64(timestamp.Nanos)).UTC().Format(time.RFC3339Nano),
	}
	encoded, err := json.Marshal(anchor)
	if err != nil {
		return nil, fmt.Errorf("codificar âncora: %w", err)
	}
	if err := ctx.GetStub().PutState(key, encoded); err != nil {
		return nil, fmt.Errorf("gravar âncora: %w", err)
	}
	if err := ctx.GetStub().SetEvent("AnchorRecorded", encoded); err != nil {
		return nil, fmt.Errorf("emitir evento: %w", err)
	}
	return anchor, nil
}

func anchorKey(eventID string) string {
	return "event:" + strings.ToLower(eventID)
}

func main() {
	chaincode, err := contractapi.NewChaincode(&AnchorContract{})
	if err != nil {
		panic(fmt.Errorf("criar chaincode: %w", err))
	}
	if err := chaincode.Start(); err != nil {
		panic(fmt.Errorf("iniciar chaincode: %w", err))
	}
}
