<?php

declare(strict_types=1);

/*
 * This file is part of the NovoSGA project.
 *
 * (c) Rogerio Lino <rogeriolino@gmail.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

namespace App\Controller\Api;

use App\Repository\LocalRepository;
use App\Service\AtendimentoService;
use App\Service\FilaService;
use App\Service\UnidadeService;
use App\Service\UsuarioService;
use Exception;
use Novosga\Entity\UsuarioInterface;
use Novosga\Service\FilaServiceInterface;
use Novosga\Service\UsuarioServiceInterface;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * FilasController
 *
 * @author Rogério Lino <rogeriolino@gmail.com>
 */
#[Route('/api/filas')]
class FilasController extends AbstractController
{
    /**
     * Retorna a lista de atendimentos do usuário atual na unidade informada.
     */
    #[Route('/{unidadeId}', methods: ['GET'])]
    public function atendimentosUsuario(
        FilaService $filaService,
        UsuarioService $usuarioService,
        UnidadeService $unidadeService,
        int $unidadeId,
    ): Response {
        /** @var UsuarioInterface */
        $usuario = $this->getUser();
        $unidade = $unidadeService->getById($unidadeId);
        $servicos = $usuarioService->getServicosUnidade($usuario, $unidade);
        $atendimentos = $filaService->getFilaAtendimento($unidade, $usuario, $servicos);

        return $this->json($atendimentos);
    }

    /**
     * Atualiza o statuso do atendimento atual do usuário para o novo status
     * informado.
     */
    #[Route('', methods: ['PUT'])]
    public function alteraStatus(Request $request, AtendimentoService $atendimentoService): Response
    {
        /** @var UsuarioInterface */
        $usuario = $this->getUser();
        $novoStatus = $request->get('novoStatus', '');
        $atendimento = $atendimentoService->alteraStatusAtendimentoUsuario($usuario, $novoStatus);

        return $this->json($atendimento);
    }

    /**
     * Chama o próximo atendimento da fila.
     */
    #[Route('/{unidadeId}/chamar', methods: ['POST'])]
    public function chamarProximo(
        Request $request,
        AtendimentoService $atendimentoService,
        UsuarioService $usuarioService,
        UnidadeService $unidadeService,
        LocalRepository $localRepository,
        int $unidadeId,
    ): Response {
        /** @var UsuarioInterface */
        $usuario = $this->getUser();
        $unidade = $unidadeService->getById($unidadeId);

        if (!$unidade) {
            return $this->json(['error' => 'Unidade não encontrada'], 404);
        }

        // Obtém parâmetros do request ou das metas do usuário
        $data = json_decode($request->getContent(), true) ?? [];

        // Local (obrigatório)
        $localId = $data['localId'] ?? null;
        if (!$localId) {
            $localMeta = $usuarioService->meta($usuario, UsuarioServiceInterface::ATTR_ATENDIMENTO_LOCAL);
            $localId = $localMeta?->getValue();
        }

        if (!$localId) {
            return $this->json(['error' => 'Local não informado'], 400);
        }

        $local = $localRepository->find($localId);
        if (!$local) {
            return $this->json(['error' => 'Local não encontrado'], 404);
        }

        // Número do local
        $numeroLocal = $data['numeroLocal'] ?? null;
        if ($numeroLocal === null) {
            $numeroMeta = $usuarioService->meta($usuario, UsuarioServiceInterface::ATTR_ATENDIMENTO_NUM_LOCAL);
            $numeroLocal = $numeroMeta ? (int) $numeroMeta->getValue() : 1;
        } else {
            $numeroLocal = (int) $numeroLocal;
        }

        // Tipo de atendimento
        $tipo = $data['tipo'] ?? null;
        if (!$tipo || !in_array($tipo, [
            FilaServiceInterface::TIPO_TODOS,
            FilaServiceInterface::TIPO_NORMAL,
            FilaServiceInterface::TIPO_PRIORIDADE,
            FilaServiceInterface::TIPO_AGENDAMENTO,
        ])) {
            // Tenta obter das metas do usuário
            $tipoMeta = $usuarioService->meta($usuario, 'atendimento.tipo');
            $tipo = $tipoMeta?->getValue() ?? FilaServiceInterface::TIPO_TODOS;
        }

        // Serviços
        $servicosUsuario = $usuarioService->getServicosUnidade($usuario, $unidade);
        if (isset($data['servicos']) && is_array($data['servicos']) && !empty($data['servicos'])) {
            // Filtra apenas os serviços informados que o usuário tem acesso
            $servicosIds = array_map('intval', $data['servicos']);
            $servicosUsuario = array_filter(
                $servicosUsuario,
                fn($su) => in_array($su->getServico()->getId(), $servicosIds)
            );
        }

        if (empty($servicosUsuario)) {
            return $this->json(['error' => 'Nenhum serviço disponível para o usuário'], 400);
        }

        // Chama o próximo atendimento
        $atendimento = $atendimentoService->chamarProximo(
            $unidade,
            $usuario,
            $local,
            $tipo,
            $servicosUsuario,
            $numeroLocal
        );

        if (!$atendimento) {
            return $this->json(['message' => 'Não há próximo atendimento disponível'], 404);
        }

        return $this->json($atendimento);
    }

    /**
     * Marca o atendimento atual do usuário como "não compareceu".
     */
    #[Route('/nao-compareceu', methods: ['POST'])]
    public function naoCompareceu(
        AtendimentoService $atendimentoService,
    ): Response {
        /** @var UsuarioInterface */
        $usuario = $this->getUser();

        // Obtém o atendimento atual do usuário
        $atendimento = $atendimentoService->getAtendimentoAndamento($usuario, null);

        if (!$atendimento) {
            return $this->json(['error' => 'Não há atendimento em andamento'], 404);
        }

        try {
            $atendimentoService->naoCompareceu($atendimento, $usuario);

            return $this->json([
                'message' => 'Atendimento marcado como não compareceu',
                'atendimento' => $atendimento,
            ]);
        } catch (Exception $e) {
            return $this->json(['error' => $e->getMessage()], 400);
        }
    }
}
