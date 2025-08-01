package mcpserver

import (
	_ "embed"

	"github.com/redhat-appstudio/tssc/pkg/constants"
	"github.com/redhat-appstudio/tssc/pkg/mcptools"

	"github.com/mark3labs/mcp-go/server"
)

//go:embed instructions.md
var instructionsBytes []byte

type MCPServer struct {
	s *server.MCPServer // mcp server instance
}

func (m *MCPServer) AddTools(tools ...mcptools.Interface) {
	for _, tool := range tools {
		tool.Init(m.s)
	}
}

func (m *MCPServer) Start() error {
	return server.ServeStdio(m.s)
}

func NewMCPServer() *MCPServer {
	return &MCPServer{s: server.NewMCPServer(
		constants.AppName,
		"1.6.0",
		server.WithToolCapabilities(true),
		server.WithPromptCapabilities(true),
		server.WithLogging(),
		server.WithInstructions(string(instructionsBytes)),
	)}
}
